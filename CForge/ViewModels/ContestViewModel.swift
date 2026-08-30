import SwiftUI

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
    /// Two-way search binding — debounced 300 ms before filtering
    @Published var searchQuery: String = ""
    /// Filtered + sorted contest list, updated reactively via searchQuery debounce
    @Published private(set) var filteredResults: [CFContest] = []
    /// Staleness state for the banner — true when data is older than 5 minutes
    @Published private(set) var isDataStale: Bool = false
    @Published private(set) var dataLastUpdated: Date? = nil

    // MARK: - Dependencies

    private let repository: ContestRepository
    private var observationTasks: [Task<Void, Never>] = []

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
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await state in await repository.wsConnectionState {
                await MainActor.run { self.connectionState = state }
            }
        })

        // Live verdict events → VerdictToast
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await submission in await repository.verdictReceived {
                await MainActor.run { self.incomingVerdict = submission }
            }
        })

        // Staleness tracking — drives StalenessBanner
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            for await date in await repository.dataLastUpdated {
                await MainActor.run {
                    self.dataLastUpdated = date
                    if let date {
                        self.isDataStale = Date().timeIntervalSince(date) > 300
                    }
                }
            }
        })

        // Debounce search — 300 ms after last keystroke before re-filtering.
        // Uses a separate observation task that reads the published searchQuery.
        observationTasks.append(Task { [weak self] in
            guard let self else { return }
            var previousQuery: String = ""
            while !Task.isCancelled {
                let query = await MainActor.run { self.searchQuery }
                if query != previousQuery {
                    previousQuery = query
                    let contests = await MainActor.run { self.state.contests }
                    let filtered = query.isEmpty
                        ? contests.sorted { $0.startTime < $1.startTime }
                        : contests.filter { $0.name.localizedCaseInsensitiveContains(query) }
                                  .sorted { $0.startTime < $1.startTime }
                    await MainActor.run { self.filteredResults = filtered }
                }
                try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms debounce
            }
        })
    }
}

// MARK: - Private

private extension ContestViewModel {
    func errorMessage(from error: Error) -> String {
        (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
}
