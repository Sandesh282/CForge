import SwiftUI

// MARK: - ProfileViewModel

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - View State

    enum ViewState {
        case idle
        case loading
        case loaded(ProfileSnapshot)
        case error(String)
    }

    /// A snapshot of all profile data needed by the UI.
    struct ProfileSnapshot {
        let user: CodeforcesUser
        let ratingHistory: [RatingChange]
        let solvedCount: Int
    }

    // MARK: - Published State

    @Published private(set) var state: ViewState = .idle
    @Published private(set) var connectionState: WebSocketConnectionState = .disconnected
    /// Incremental live rating value pushed by WebSocket — overlaid on top of REST data
    @Published private(set) var liveRating: Int? = nil
    /// Latest verdict received via WebSocket for toast display
    @Published var incomingVerdict: Submission? = nil
    /// Staleness state for the banner — true when data is older than 1 hour (rating history TTL)
    @Published private(set) var isDataStale: Bool = false
    @Published private(set) var dataLastUpdated: Date? = nil

    // MARK: - Dependencies

    private let repository: ProfileRepository
    private var observationTasks: [Task<Void, Never>] = []

    // MARK: - Init

    init(repository: ProfileRepository = ProfileRepository()) {
        self.repository = repository
        bindRepositoryPublishers()
    }

    // MARK: - Intents

    func loadProfile(handle: String) async {
        guard case .idle = state else { return }
        state = .loading
        AppLog.debug("ProfileVM: Loading profile for \(handle)", category: .ui)

        do {
            // Fetch all three data points concurrently
            async let user         = repository.getProfile(handle: handle)
            async let history      = repository.getRatingHistory(handle: handle)
            async let solvedCount  = repository.getSolvedCount(handle: handle)

            let snapshot = try await ProfileSnapshot(
                user: user,
                ratingHistory: history,
                solvedCount: solvedCount
            )
            state = .loaded(snapshot)
            AppLog.debug("ProfileVM: Profile loaded for \(handle)", category: .ui)

            // Start WebSocket subscription after initial load
            await repository.connectWebSocket(handle: handle)

        } catch {
            state = .error(errorMessage(from: error))
            AppLog.error("ProfileVM: Load error — \(error)", category: .ui)
        }
    }

    func refresh(handle: String) async {
        do {
            async let user         = repository.getProfile(handle: handle, forceRefresh: true)
            async let history      = repository.getRatingHistory(handle: handle)
            async let solvedCount  = repository.getSolvedCount(handle: handle, forceRefresh: true)

            let snapshot = try await ProfileSnapshot(
                user: user,
                ratingHistory: history,
                solvedCount: solvedCount
            )
            state = .loaded(snapshot)
        } catch {
            AppLog.error("ProfileVM: Refresh failed — \(error)", category: .ui)
        }
    }

    func retry(handle: String) async {
        state = .idle
        await loadProfile(handle: handle)
    }

    func dismissVerdict() {
        incomingVerdict = nil
    }

    // MARK: - Repository Bindings

    private func bindRepositoryPublishers() {
        // Live rating update from WebSocket
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await (_, newRating) in await repository.ratingUpdated {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.liveRating = newRating
                    }
                }
            }
        })

        // WebSocket connection state
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await state in await repository.wsConnectionState {
                await MainActor.run { self.connectionState = state }
            }
        })

        // Staleness tracking — drives StalenessBanner (TTL: 60 min for rating history)
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await date in await repository.dataLastUpdated {
                await MainActor.run {
                    self.dataLastUpdated = date
                    if let date {
                        self.isDataStale = Date().timeIntervalSince(date) > 3600
                    }
                }
            }
        })
    }
}

// MARK: - Private

private extension ProfileViewModel {
    func errorMessage(from error: Error) -> String {
        (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
}
