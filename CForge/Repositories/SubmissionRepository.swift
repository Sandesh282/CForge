import Foundation

// MARK: - SubmissionRepository
//
// Actor-based single source of truth for submission data.
//
// Responsibilities:
//  - 30-second TTL in-memory cache per (handle, contestId) pair
//  - In-flight deduplication: concurrent fetches for the same key join the same Task
//  - WebSocket integration: listens for .submissionVerdict events, throttles at 500 ms,
//    prepends live verdicts to the cache and republishes via verdictReceived
//
// The 30s TTL is intentionally short because submission verdicts change after judging.

actor SubmissionRepository {

    // MARK: - Cache

    private struct CacheKey: Hashable {
        let handle: String
        let contestId: Int
    }

    private struct CacheEntry {
        var submissions: [Submission]
        var fetchTime: Date
    }

    private enum CacheTTL {
        static let submissions: TimeInterval = 30   // verdicts are time-sensitive
    }

    private var cache: [CacheKey: CacheEntry] = [:]
    private var ongoingTasks: [CacheKey: Task<[Submission], Error>] = [:]

    // MARK: - Services

    private let service: ProblemServiceProtocol
    private let wsService: WebSocketServiceProtocol

    // MARK: - AsyncStream Outputs

    private var verdictContinuations: [UUID: AsyncStream<Submission>.Continuation] = [:]
    private var wsTask: Task<Void, Never>?

    // MARK: - Latest-Wins Throttle State
    //
    // Actor isolation guarantees no races on these fields.
    // On first event arrival the throttle window opens; subsequent events within
    // the window simply overwrite `pendingVerdict`. When the window closes the
    // *latest* value is flushed — matching Combine's .throttle(latest: true) semantics.

    private var pendingVerdict: Submission?
    private var verdictThrottleTask: Task<Void, Never>?

    var verdictReceived: AsyncStream<Submission> {
        AsyncStream { continuation in
            let id = UUID()
            verdictContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeVerdictContinuation(id: id) }
            }
        }
    }

    private func removeVerdictContinuation(id: UUID) { verdictContinuations.removeValue(forKey: id) }

    // MARK: - Init

    init(
        service: ProblemServiceProtocol = ProblemService(),
        wsService: WebSocketServiceProtocol = LiveWebSocketService()
    ) {
        self.service = service
        self.wsService = wsService
        bindWebSocketEvents()
    }

    // MARK: - Fetch

    /// Fetches contest submissions for a given handle.
    /// Serves from the 30-second TTL cache; concurrent callers share the same in-flight Task.
    func getContestSubmissions(
        contestId: Int,
        handle: String,
        forceRefresh: Bool = false
    ) async throws -> [Submission] {
        let key = CacheKey(handle: handle, contestId: contestId)

        // Cache hit
        if !forceRefresh,
           let entry = cache[key],
           Date().timeIntervalSince(entry.fetchTime) < CacheTTL.submissions {
            AppLog.debug("SubmissionRepository: Cache hit for \(handle)/\(contestId)", category: .cache)
            return entry.submissions
        }

        // In-flight deduplication
        if let ongoing = ongoingTasks[key] {
            AppLog.debug("SubmissionRepository: Joining ongoing fetch for \(handle)/\(contestId)", category: .network)
            return try await ongoing.value
        }

        let task = Task<[Submission], Error> {
            do {
                let submissions = try await self.service.fetchContestSubmissions(
                    contestId: contestId,
                    handle: handle
                )
                let entry = CacheEntry(submissions: submissions, fetchTime: Date())
                self.cache[key] = entry
                self.ongoingTasks.removeValue(forKey: key)
                AppLog.debug("SubmissionRepository: Fetched \(submissions.count) submissions", category: .network)
                return submissions
            } catch {
                self.ongoingTasks.removeValue(forKey: key)
                throw error
            }
        }

        ongoingTasks[key] = task
        return try await task.value
    }

    // MARK: - WebSocket Binding

    private func bindWebSocketEvents() {
        wsTask = Task { [weak self] in
            // Access wsService via optional chain — wsService is a non-optional `let` on
            // the actor, so it cannot appear in a [weak wsService] capture list.
            // Using self?.wsService also avoids promoting self to a strong reference
            // across the indefinitely-suspending for-await loop (retain-cycle fix).
            guard let wsService = await self?.wsService else { return }

            for await event in wsService.eventStream {
                guard case .submissionVerdict(let submission) = event else { continue }
                await self?.scheduleVerdictEmission(submission)
            }
        }
    }

    /// Records the latest verdict and opens a 500 ms flush window if one isn't already open.
    /// Implements latest-wins throttle: every event within the window overwrites the pending
    /// slot; the window-close flush always delivers the *latest* arrived verdict.
    private func scheduleVerdictEmission(_ submission: Submission) {
        pendingVerdict = submission
        guard verdictThrottleTask == nil else { return }  // window already open
        verdictThrottleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)  // 500 ms window
            await self?.flushPendingVerdict()
        }
    }

    private func flushPendingVerdict() {
        verdictThrottleTask = nil
        guard let verdict = pendingVerdict else { return }
        pendingVerdict = nil
        prependToCache(submission: verdict)
        emitVerdict(verdict)
    }

    /// Inserts the incoming live verdict at the front of all cache entries for its author.
    private func prependToCache(submission: Submission) {
        let handle = submission.author.members.first?.handle ?? ""
        guard !handle.isEmpty else { return }

        for key in cache.keys where key.handle == handle {
            var entry = cache[key]!
            // Avoid duplicates — if the same submission id already exists, replace it
            entry.submissions.removeAll { $0.id == submission.id }
            entry.submissions.insert(submission, at: 0)
            cache[key] = entry
        }

        AppLog.debug("SubmissionRepository: Live verdict prepended for \(handle)", category: .cache)
    }

    private func emitVerdict(_ submission: Submission) {
        verdictContinuations.values.forEach { $0.yield(submission) }
    }
}
