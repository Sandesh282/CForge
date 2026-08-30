import Foundation
import SwiftData

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

    // MARK: - AsyncStream Outputs
    //
    // Each property vends a fresh AsyncStream backed by a stored continuation.
    // Downstream consumers (ViewModels) iterate these with `for await`.

    private var ratingContinuations:  [UUID: AsyncStream<(String, Int)>.Continuation] = [:]
    private var stateContinuations:   [UUID: AsyncStream<WebSocketConnectionState>.Continuation] = [:]
    private var updatedContinuations: [UUID: AsyncStream<Date?>.Continuation] = [:]
    private var _lastUpdated: Date?

    /// Yields `(handle, newRating)` whenever a live rating-update arrives.
    var ratingUpdated: AsyncStream<(String, Int)> {
        AsyncStream { continuation in
            let id = UUID()
            ratingContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeRatingContinuation(id: id) }
            }
        }
    }

    /// Yields the current WebSocket connection state and all subsequent changes.
    var wsConnectionState: AsyncStream<WebSocketConnectionState> {
        AsyncStream { continuation in
            let id = UUID()
            stateContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeStateContinuation(id: id) }
            }
        }
    }

    /// Yields the timestamp of the last successful data refresh (nil until first load).
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

    // Continuation cleanup helpers (must run on the actor)
    private func removeRatingContinuation(id: UUID)  { ratingContinuations.removeValue(forKey: id) }
    private func removeStateContinuation(id: UUID)   { stateContinuations.removeValue(forKey: id) }
    private func removeUpdatedContinuation(id: UUID) { updatedContinuations.removeValue(forKey: id) }

    private var wsBindingTask: Task<Void, Never>?

    // MARK: - Latest-Wins Rating Throttle State
    //
    // Actor isolation guarantees no races on these fields.
    // Rating updates during live contests can burst at high frequency;
    // we open a 1-second window and flush the *latest* value on close.
    // Trailing-edge latest-wins throttle: unlike Combine's .throttle(latest: true)
    // which emits the first event immediately, this delays the first emission by
    // the full 1 s window duration.

    private var pendingRating: (String, Int)?
    private var ratingThrottleTask: Task<Void, Never>?

    deinit {
        // Explicitly cancel long-lived tasks so child for-await loops terminate
        // promptly on actor deallocation. Task.cancel() is synchronous and safe
        // to call from a non-isolated deinit.
        wsBindingTask?.cancel()
        ratingThrottleTask?.cancel()
    }

    // MARK: - Persistence

    private let modelContext: ModelContext

    // MARK: - Init

    init(
        profileService: ProfileServiceProtocol = ProfileService(),
        wsService: WebSocketServiceProtocol = LiveWebSocketService(),
        modelContainer: ModelContainer = PersistenceController.shared.container
    ) {
        self.profileService = profileService
        self.wsService = wsService
        self.modelContext = ModelContext(modelContainer)
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
        // 1. Serve from SwiftData immediately (offline-first)
        if !forceRefresh {
            let descriptor = FetchDescriptor<PersistedRatingChange>(
                predicate: #Predicate { $0.handle == handle },
                sortBy: [SortDescriptor(\.ratingUpdateTimeSeconds)]
            )
            let persisted = (try? modelContext.fetch(descriptor)) ?? []
            if !persisted.isEmpty {
                AppLog.debug("ProfileRepository: \(persisted.count) rating changes from SwiftData", category: .cache)
                let lastSaved = persisted.map { $0.ratingUpdateTimeSeconds }.max().map {
                    Date(timeIntervalSince1970: TimeInterval($0))
                } ?? Date()
                emitUpdated(lastSaved)
                // Background refresh if in-memory cache is stale
                if cachedRatingHistory == nil {
                    Task { try? await self.refreshRatingHistoryInBackground(handle: handle) }
                }
                return persisted.map { $0.toDomain() }
            }
        }

        // 2. In-memory TTL cache
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
                for change in history {
                    self.modelContext.insert(PersistedRatingChange(from: change))
                }
                try? self.modelContext.save()
                self.emitUpdated(Date())
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

    private func refreshRatingHistoryInBackground(handle: String) async throws {
        let history = try await profileService.fetchRatingHistory(handle: handle)
        for change in history {
            modelContext.insert(PersistedRatingChange(from: change))
        }
        try? modelContext.save()
        emitUpdated(Date())
        cachedRatingHistory = history
        ratingHistoryFetchTime = Date()
        AppLog.debug("ProfileRepository: Background rating history refresh complete", category: .cache)
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
        wsBindingTask = Task { [weak self] in
            guard let wsService = await self?.wsService else { return }

            // Fan-out: two concurrent child tasks — one for events, one for state changes.
            await withTaskGroup(of: Void.self) { group in

                // Rating update events — latest-wins throttle at 1 s.
                // Every event in the window updates the pending slot; the window-close
                // flush delivers the *latest* rating, matching .throttle(latest: true).
                group.addTask { [weak self] in
                    for await event in wsService.eventStream {
                        guard case .ratingUpdate(let handle, let rating) = event else { continue }
                        await self?.scheduleRatingEmission((handle, rating))
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

    /// Records the latest rating pair and opens a 1 s flush window if none is open.
    private func scheduleRatingEmission(_ value: (String, Int)) {
        pendingRating = value
        guard ratingThrottleTask == nil else { return }  // window already open
        ratingThrottleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 s window
            await self?.flushPendingRating()
        }
    }

    private func flushPendingRating() {
        ratingThrottleTask = nil
        guard let (handle, rating) = pendingRating else { return }
        pendingRating = nil
        persistRatingUpdate(handle: handle, newRating: rating)
        invalidateProfileCache()
        emitRating((handle, rating))
    }

    private func invalidateProfileCache() {
        cachedProfile = nil
        profileFetchTime = nil
    }

    // MARK: - Emission Helpers

    private func emitRating(_ value: (String, Int)) {
        ratingContinuations.values.forEach { $0.yield(value) }
    }

    private func emitState(_ state: WebSocketConnectionState) {
        stateContinuations.values.forEach { $0.yield(state) }
    }

    private func emitUpdated(_ date: Date?) {
        _lastUpdated = date
        updatedContinuations.values.forEach { $0.yield(date) }
    }

    /// Upserts the live rating into the most recent `PersistedRatingChange` for `handle`.
    /// Idempotent: re-sending the same rating produces no new row.
    private func persistRatingUpdate(handle: String, newRating: Int) {
        let descriptor = FetchDescriptor<PersistedRatingChange>(
            predicate: #Predicate { $0.handle == handle },
            sortBy: [SortDescriptor(\.ratingUpdateTimeSeconds, order: .reverse)]
        )
        guard let mostRecent = (try? modelContext.fetch(descriptor))?.first else { return }
        mostRecent.newRating = newRating
        try? modelContext.save()
        AppLog.debug("ProfileRepository: Persisted live rating \(newRating) for \(handle)", category: .cache)
    }
}
