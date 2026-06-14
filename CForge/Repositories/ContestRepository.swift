import Foundation
import Combine

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

    // MARK: - WebSocket State

    private let wsService: WebSocketServiceProtocol
    private var wsTask: Task<Void, Never>?

    // MARK: - Published Outputs (via AsyncStream bridge)
    // These subjects are internal; ViewModels observe via async sequences.

    private let _standingsUpdated = PassthroughSubject<(Int, [StandingsRow]), Never>()
    private let _verdictReceived = PassthroughSubject<Submission, Never>()
    private let _connectionStateChanged = PassthroughSubject<WebSocketConnectionState, Never>()

    nonisolated var standingsUpdated: AnyPublisher<(Int, [StandingsRow]), Never> {
        _standingsUpdated.eraseToAnyPublisher()
    }
    nonisolated var verdictReceived: AnyPublisher<Submission, Never> {
        _verdictReceived.eraseToAnyPublisher()
    }
    nonisolated var wsConnectionState: AnyPublisher<WebSocketConnectionState, Never> {
        _connectionStateChanged.eraseToAnyPublisher()
    }

    // MARK: - Init

    init(
        restService: ContestServiceProtocol = ContestService(),
        wsService: WebSocketServiceProtocol = LiveWebSocketService()
    ) {
        self.restService = restService
        self.wsService = wsService
        bindWebSocketEvents()
    }

    // MARK: - REST: Fetch Upcoming Contests

    func getUpcomingContests(forceRefresh: Bool = false) async throws -> [CFContest] {
        // Serve from cache if within TTL
        if !forceRefresh, let cached = cachedContests, let fetchTime = contestsFetchTime {
            if Date().timeIntervalSince(fetchTime) < CachePolicy.contestListTTL {
                AppLog.debug("ContestRepository: Returning cached contests", category: .cache)
                return cached
            }
        }

        // Deduplicate in-flight requests
        if let ongoing = ongoingFetchTask {
            AppLog.debug("ContestRepository: Joining ongoing fetch task", category: .network)
            return try await ongoing.value
        }

        let task = Task<[CFContest], Error> {
            do {
                let contests = try await self.restService.fetchUpcomingContests()
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

    // MARK: - WebSocket: Subscribe to Live Contest

    func subscribeToLiveContest(contestId: Int) {
        // NOTE: CForge is a tracker app — users do not submit from the phone.
        // Live verdict push is forward-looking infrastructure for when Codeforces
        // exposes an official WebSocket/push API, or when a BFF proxy is built (Issue 18).
        // The URL below is a placeholder and will not connect in production.
        guard let url = URL(string: "wss://api.cforge.app/ws/contest/\(contestId)") else { return }
        wsService.connect(to: url)
    }

    func disconnectFromLiveContest() {
        wsService.disconnect()
    }

    // MARK: - WebSocket Binding

    private func bindWebSocketEvents() {
        wsTask = Task { [weak wsService, weak self] in
            guard let wsService else { return }

            // Throttle verdict events to one per 500ms to prevent UI stutter
            var cancellables = Set<AnyCancellable>()

            wsService.events
                .compactMap { event -> Submission? in
                    if case .submissionVerdict(let s) = event { return s } else { return nil }
                }
                .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] submission in
                    Task { await self?._verdictReceived.send(submission) }
                }
                .store(in: &cancellables)

            wsService.connectionState
                .sink { [weak self] state in
                    Task { await self?._connectionStateChanged.send(state) }
                }
                .store(in: &cancellables)

            // Keep the task alive by waiting indefinitely (cancelled via wsTask?.cancel())
            try? await Task.sleep(nanoseconds: .max)
        }
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
