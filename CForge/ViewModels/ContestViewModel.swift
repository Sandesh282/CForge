import SwiftUI
import Combine

// MARK: - ContestViewModel

@MainActor
final class ContestViewModel: ObservableObject {

    // MARK: - View State

    enum ViewState {
        case idle
        case loading
        case loaded([CFContest])
        case error(String)

        var contests: [CFContest] {
            if case .loaded(let c) = self { return c } else { return [] }
        }
    }

    // MARK: - Published State

    @Published private(set) var state: ViewState = .idle
    @Published private(set) var connectionState: WebSocketConnectionState = .disconnected
    @Published private(set) var isRefreshing = false
    /// Latest live verdict pushed by WebSocket — drives VerdictToast overlay
    @Published var incomingVerdict: Submission? = nil

    // MARK: - Dependencies

    private let repository: ContestRepository
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(repository: ContestRepository = ContestRepository()) {
        self.repository = repository
        bindRepositoryPublishers()
    }

    // MARK: - Intents

    func loadContests() async {
        guard case .idle = state else { return }
        state = .loading
        AppLog.debug("ContestVM: Loading contests", category: .ui)

        do {
            let contests = try await repository.getUpcomingContests()
            state = .loaded(contests)
            AppLog.debug("ContestVM: Loaded \(contests.count) contests", category: .ui)
        } catch {
            state = .error(errorMessage(from: error))
            AppLog.error("ContestVM: \(error)", category: .ui)
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let contests = try await repository.getUpcomingContests(forceRefresh: true)
            state = .loaded(contests)
        } catch {
            // On refresh failure, keep the existing data but surface the error gently
            AppLog.error("ContestVM: Refresh failed — \(error)", category: .ui)
        }
    }

    func retry() async {
        state = .idle
        await loadContests()
    }

    func dismissVerdict() {
        incomingVerdict = nil
    }

    // MARK: - Helpers

    func filteredContests(query: String) -> [CFContest] {
        let contests = state.contests
        guard !query.isEmpty else {
            return contests.sorted { $0.startTime < $1.startTime }
        }
        return contests
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Repository Bindings

    private func bindRepositoryPublishers() {
        // WebSocket connection state → UI indicator
        repository.wsConnectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)

        // Live verdict events → VerdictToast
        repository.verdictReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] submission in
                self?.incomingVerdict = submission
            }
            .store(in: &cancellables)
    }
}

// MARK: - Private

private extension ContestViewModel {
    func errorMessage(from error: Error) -> String {
        (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
}
