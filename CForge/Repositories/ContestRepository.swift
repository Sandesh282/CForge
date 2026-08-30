import Foundation
import SwiftData

// MARK: - ContestRepository

/// Actor-based repository that is the single source of truth for contest data.
/// It merges REST responses (initial load / pull-to-refresh) with real-time
/// WebSocket events (live standings, rating updates).
///
/// Architecture note: The repository owns the WebSocket subscription so that
/// ViewModels remain stateless w.r.t. connection management. Throttling of
/// high-frequency events is applied here — at the repository boundary —
/// before any data reaches the ViewModel or UI.
actor ContestRepository {

    // MARK: - Cache Policy

    private enum CachePolicy {
        static let contestListTTL: TimeInterval = 300  // 5 minutes
    }

    // MARK: - REST State

    private let restService: ContestServiceProtocol
    private var cachedContests: [CFContest]?
    private var contestsFetchTime: Date?
    private var ongoingFetchTask: Task<[CFContest], Error>?

    // MARK: - Persistence

    private let modelContext: ModelContext

    // MARK: - WebSocket State

    private let wsService: WebSocketServiceProtocol
    private var wsTask: Task<Void, Never>?

    // MARK: - Latest-Wins Verdict Throttle State
    //
    // Actor isolation guarantees no races on these fields.
    // Verdict events during live contests can burst rapidly;
    // we open a 500 ms window and flush the *latest* value on close.
    // This is a trailing-edge latest-wins throttle — unlike Combine's
    // .throttle(latest: true) which emits immediately then again at window end,
    // this delays the first emission by the full window duration.

    private var pendingVerdict: Submission?
    private var verdictThrottleTask: Task<Void, Never>?

    deinit {
        // Explicitly cancel the long-lived binding task so that its child
        // for-await loops terminate promptly instead of running until the
        // next AsyncStream element arrives. Task.cancel() is synchronous
        // and safe to call from a non-isolated deinit.
        wsTask?.cancel()
        verdictThrottleTask?.cancel()
    }

    // MARK: - AsyncStream Outputs

    private var standingsContinuations: [UUID: AsyncStream<(Int, [StandingsRow])>.Continuation] = [:]
    private var verdictContinuations:   [UUID: AsyncStream<Submission>.Continuation] = [:]
    private var stateContinuations:     [UUID: AsyncStream<WebSocketConnectionState>.Continuation] = [:]
    private var updatedContinuations:   [UUID: AsyncStream<Date?>.Continuation] = [:]
    private var _lastUpdated: Date?

    var standingsUpdated: AsyncStream<(Int, [StandingsRow])> {
        AsyncStream { continuation in
            let id = UUID()
            standingsContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeStandingsContinuation(id: id) }
            }
        }
    }

    var verdictReceived: AsyncStream<Submission> {
        AsyncStream { continuation in
            let id = UUID()
            verdictContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeVerdictContinuation(id: id) }
            }
        }
    }

    var wsConnectionState: AsyncStream<WebSocketConnectionState> {
        AsyncStream { continuation in
            let id = UUID()
            stateContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeStateContinuation(id: id) }
            }
        }
    }

    /// Emits the timestamp of the last successful data refresh (Network or persisted).
    /// Nil until the first data is served. ViewModels use this to drive the staleness banner.
    var dataLastUpdated: AsyncStream<Date?> {
        let current = _lastUpdated
        return AsyncStream { continuation in
            let id = UUID()
            continuation.yield(current)
            updatedContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeUpdatedContinuation(id: id) }
            }
        }
    }

    private func removeStandingsContinuation(id: UUID) { standingsContinuations.removeValue(forKey: id) }
    private func removeVerdictContinuation(id: UUID)   { verdictContinuations.removeValue(forKey: id) }
    private func removeStateContinuation(id: UUID)     { stateContinuations.removeValue(forKey: id) }
    private func removeUpdatedContinuation(id: UUID)   { updatedContinuations.removeValue(forKey: id) }

    // MARK: - Init

    init(
        restService: ContestServiceProtocol = ContestService(),
        wsService: WebSocketServiceProtocol = LiveWebSocketService(),
        modelContainer: ModelContainer = PersistenceController.shared.container
    ) {
        self.restService = restService
        self.wsService = wsService
        self.modelContext = ModelContext(modelContainer)
        bindWebSocketEvents()
    }

    // MARK: - REST: Fetch Upcoming Contests

    func getUpcomingContests(forceRefresh: Bool = false) async throws -> [CFContest] {
        // 1. Serve from SwiftData immediately — offline-first cold launch path
        if !forceRefresh {
            let persisted = (try? modelContext.fetch(FetchDescriptor<PersistedContest>())) ?? []
            let upcoming = persisted
                .filter { $0.phase == "BEFORE" }
                .map { $0.toDomain() }
                .sorted { ($0.startTimeSeconds ?? 0) < ($1.startTimeSeconds ?? 0) }
            if !upcoming.isEmpty {
                AppLog.debug("ContestRepository: \(upcoming.count) contests from SwiftData", category: .cache)
                // Report the most-recent persisted timestamp to drive the staleness banner
                let lastSaved = persisted.map { $0.updatedAt }.max() ?? Date()
                emitUpdated(lastSaved)
                // Background refresh if in-memory cache is stale
                if isCacheStale() {
                    Task { try? await self.refreshInBackground() }
                }
                return upcoming
            }
        }

        // 2. In-memory TTL cache
        if !forceRefresh, let cached = cachedContests, let fetchTime = contestsFetchTime {
            if Date().timeIntervalSince(fetchTime) < CachePolicy.contestListTTL {
                AppLog.debug("ContestRepository: Returning cached contests", category: .cache)
                return cached
            }
        }

        // 3. Network fetch + deduplicate in-flight + persist
        if let ongoing = ongoingFetchTask {
            AppLog.debug("ContestRepository: Joining ongoing fetch task", category: .network)
            return try await ongoing.value
        }

        let task = Task<[CFContest], Error> {
            do {
                let contests = try await self.restService.fetchUpcomingContests()
                for contest in contests {
                    self.modelContext.insert(PersistedContest(from: contest))
                }
                try? self.modelContext.save()
                self.emitUpdated(Date())
                self.cachedContests = contests
                self.contestsFetchTime = Date()
                self.ongoingFetchTask = nil
                AppLog.debug("ContestRepository: Fetched \(contests.count) contests", category: .cache)
                return contests
            } catch {
                self.ongoingFetchTask = nil
                throw error
            }
        }

        ongoingFetchTask = task
        return try await task.value
    }

    // MARK: - Private Persistence Helpers

    private func isCacheStale() -> Bool {
        guard let fetchTime = contestsFetchTime else { return true }
        return Date().timeIntervalSince(fetchTime) >= CachePolicy.contestListTTL
    }

    private func refreshInBackground() async throws {
        let contests = try await restService.fetchUpcomingContests()
        for contest in contests {
            modelContext.insert(PersistedContest(from: contest))
        }
        try? modelContext.save()
        emitUpdated(Date())
        cachedContests = contests
        contestsFetchTime = Date()
        AppLog.debug("ContestRepository: Background refresh complete", category: .cache)
    }

    // MARK: - WebSocket: Subscribe to Live Contest

    func subscribeToLiveContest(contestId: Int) {
        // NOTE: CForge is a tracker app — users do not submit from the phone.
        // Live verdict push is forward-looking infrastructure pending an official
        // Codeforces push API or a custom BFF proxy. Placeholder URL below.
        guard let url = URL(string: "wss://api.cforge.app/ws/contest/\(contestId)") else { return }
        wsService.connect(to: url)
    }

    func disconnectFromLiveContest() {
        wsService.disconnect()
    }

    // MARK: - WebSocket Binding

    private func bindWebSocketEvents() {
        wsTask = Task { [weak self] in
            // Access wsService via optional chain — wsService is a non-optional `let` on
            // the actor, so it cannot appear in a [weak wsService] capture list.
            // Using self?.wsService also avoids promoting self to a strong reference
            // across the indefinitely-suspending withTaskGroup await.
            guard let wsService = await self?.wsService else { return }

            await withTaskGroup(of: Void.self) { group in

                // Verdict events — latest-wins throttle at 500 ms.
                // NOTE: SwiftData upsert on standingsUpdated is deferred — no `standingsUpdated`
                // WebSocket event exists yet (requires a BFF proxy). When the event is available,
                // update PersistedContest fields here and call modelContext.save().
                group.addTask { [weak self] in
                    for await event in wsService.eventStream {
                        guard case .submissionVerdict(let submission) = event else { continue }
                        await self?.scheduleVerdictEmission(submission)
                    }
                }

                group.addTask { [weak self] in
                    for await state in wsService.connectionStateStream {
                        await self?.emitState(state)
                    }
                }
            }
        }
    }

    /// Records the latest verdict and opens a 500 ms flush window if none is open.
    /// Trailing-edge latest-wins throttle: all events within the window overwrite the
    /// pending slot; the window-close flush always delivers the *latest* verdict.
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
        emitVerdict(verdict)
    }

    // MARK: - Emission Helpers

    private func emitVerdict(_ submission: Submission) {
        verdictContinuations.values.forEach { $0.yield(submission) }
    }

    private func emitState(_ state: WebSocketConnectionState) {
        stateContinuations.values.forEach { $0.yield(state) }
    }

    private func emitUpdated(_ date: Date?) {
        _lastUpdated = date
        updatedContinuations.values.forEach { $0.yield(date) }
    }
}

// MARK: - StandingsRow (Domain Model)

struct StandingsRow: Identifiable, Equatable {
    let id: String  // handle
    let handle: String
    let rank: Int
    let points: Double
    let penalty: Int
}
