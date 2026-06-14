import Foundation
import Combine

// MARK: - ProfileRepository

/// Actor-based repository for all user profile data.
/// Consolidates the three previously uncoordinated `ProfileAPI.swift`
/// extension calls into a single, cached, rate-limited, WebSocket-aware source of truth.
///
/// Key fixes over the previous implementation:
/// - `fetchSolvedCount` now uses count=500 (not 10,000)
/// - All three fetch calls go through `RequestScheduler` for rate-limit compliance
/// - Results are cached with separate TTLs per data type
/// - In-flight task deduplication prevents redundant concurrent fetches
actor ProfileRepository {

    // MARK: - Cache Policies

    private enum CacheTTL {
        static let profile:       TimeInterval = 300   // 5 min  — rating/rank changes infrequently
        static let ratingHistory: TimeInterval = 3600  // 60 min — historical data is static
        static let solvedCount:   TimeInterval = 120   // 2 min  — can change after submissions
    }

    // MARK: - Services

    private let profileService: ProfileServiceProtocol
    private let wsService: WebSocketServiceProtocol

    // MARK: - Cache Storage

    private var cachedProfile: CodeforcesUser?
    private var profileFetchTime: Date?

    private var cachedRatingHistory: [RatingChange]?
    private var ratingHistoryFetchTime: Date?

    private var cachedSolvedCount: Int?
    private var solvedCountFetchTime: Date?

    // MARK: - In-Flight Task Deduplication

    private var ongoingProfileTask: Task<CodeforcesUser, Error>?
    private var ongoingHistoryTask: Task<[RatingChange], Error>?
    private var ongoingSolvedTask: Task<Int, Error>?

    // MARK: - WebSocket Outputs

    private let _ratingUpdated = PassthroughSubject<(String, Int), Never>()
    private let _connectionStateChanged = PassthroughSubject<WebSocketConnectionState, Never>()

    nonisolated var ratingUpdated: AnyPublisher<(String, Int), Never> {
        _ratingUpdated.eraseToAnyPublisher()
    }
    nonisolated var wsConnectionState: AnyPublisher<WebSocketConnectionState, Never> {
        _connectionStateChanged.eraseToAnyPublisher()
    }

    private var wsBindingTask: Task<Void, Never>?

    // MARK: - Init

    init(
        profileService: ProfileServiceProtocol = ProfileService(),
        wsService: WebSocketServiceProtocol = LiveWebSocketService()
    ) {
        self.profileService = profileService
        self.wsService = wsService
        bindWebSocketEvents()
    }

    // MARK: - Profile

    func getProfile(handle: String, forceRefresh: Bool = false) async throws -> CodeforcesUser {
        if !forceRefresh, let cached = cachedProfile, let time = profileFetchTime,
           Date().timeIntervalSince(time) < CacheTTL.profile {
            AppLog.debug("ProfileRepository: Returning cached profile", category: .cache)
            return cached
        }

        if let ongoing = ongoingProfileTask {
            return try await ongoing.value
        }

        let task = Task<CodeforcesUser, Error> {
            do {
                let user = try await self.profileService.fetchProfile(handle: handle)
                self.cachedProfile = user
                self.profileFetchTime = Date()
                self.ongoingProfileTask = nil
                return user
            } catch {
                self.ongoingProfileTask = nil
                throw error
            }
        }
        ongoingProfileTask = task
        return try await task.value
    }

    // MARK: - Rating History

    func getRatingHistory(handle: String, forceRefresh: Bool = false) async throws -> [RatingChange] {
        if !forceRefresh, let cached = cachedRatingHistory, let time = ratingHistoryFetchTime,
           Date().timeIntervalSince(time) < CacheTTL.ratingHistory {
            AppLog.debug("ProfileRepository: Returning cached rating history", category: .cache)
            return cached
        }

        if let ongoing = ongoingHistoryTask {
            return try await ongoing.value
        }

        let task = Task<[RatingChange], Error> {
            do {
                let history = try await self.profileService.fetchRatingHistory(handle: handle)
                self.cachedRatingHistory = history
                self.ratingHistoryFetchTime = Date()
                self.ongoingHistoryTask = nil
                return history
            } catch {
                self.ongoingHistoryTask = nil
                throw error
            }
        }
        ongoingHistoryTask = task
        return try await task.value
    }

    // MARK: - Solved Count

    func getSolvedCount(handle: String, forceRefresh: Bool = false) async throws -> Int {
        if !forceRefresh, let cached = cachedSolvedCount, let time = solvedCountFetchTime,
           Date().timeIntervalSince(time) < CacheTTL.solvedCount {
            AppLog.debug("ProfileRepository: Returning cached solved count", category: .cache)
            return cached
        }

        if let ongoing = ongoingSolvedTask {
            return try await ongoing.value
        }

        let task = Task<Int, Error> {
            do {
                let count = try await self.profileService.fetchSolvedCount(handle: handle)
                self.cachedSolvedCount = count
                self.solvedCountFetchTime = Date()
                self.ongoingSolvedTask = nil
                return count
            } catch {
                self.ongoingSolvedTask = nil
                throw error
            }
        }
        ongoingSolvedTask = task
        return try await task.value
    }

    // MARK: - WebSocket Binding

    func connectWebSocket(handle: String) {
        guard let url = URL(string: "wss://api.cforge.app/ws/user/\(handle)") else { return }
        wsService.connect(to: url)
    }

    func disconnectWebSocket() {
        wsService.disconnect()
    }

    private func bindWebSocketEvents() {
        wsBindingTask = Task { [weak wsService, weak self] in
            guard let wsService else { return }
            var cancellables = Set<AnyCancellable>()

            // Rating update events — throttled to ≤ 1 per second to prevent
            // excessive ProfileView re-renders during burst updates in live contests.
            wsService.events
                .compactMap { event -> (String, Int)? in
                    if case .ratingUpdate(let handle, let rating) = event {
                        return (handle, rating)
                    }
                    return nil
                }
                .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
                .sink { [weak self] (handle, rating) in
                    Task {
                        // Invalidate the profile cache so next read fetches fresh data
                        await self?.invalidateProfileCache()
                        await self?._ratingUpdated.send((handle, rating))
                    }
                }
                .store(in: &cancellables)

            wsService.connectionState
                .sink { [weak self] state in
                    Task { await self?._connectionStateChanged.send(state) }
                }
                .store(in: &cancellables)

            try? await Task.sleep(nanoseconds: .max)
        }
    }

    private func invalidateProfileCache() {
        cachedProfile = nil
        profileFetchTime = nil
    }
}
