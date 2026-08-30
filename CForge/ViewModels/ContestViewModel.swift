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
    /// Two-way search binding — View writes here, ViewModel debounces and refilters.
    @Published var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            searchDebounceTask?.cancel()
            searchDebounceTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000)  // 300 ms debounce
                guard !Task.isCancelled, let self else { return }
                self.refilter()
            }
        }
    }
    /// Filtered + sorted contest list, updated reactively via searchQuery debounce and state changes
    @Published private(set) var filteredResults: [CFContest] = []
    /// Staleness state for the banner — true when data is older than 5 minutes
    @Published private(set) var isDataStale: Bool = false
    @Published private(set) var dataLastUpdated: Date? = nil

    private var searchDebounceTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let repository: ContestRepository
    /// Long-lived observation tasks. Cancelled in `deinit` — the direct equivalent of
    /// `Set<AnyCancellable>` auto-cancellation when the ViewModel deallocates.
    private var observationTasks: [Task<Void, Never>] = []

    deinit {
        observationTasks.forEach { $0.cancel() }
    }

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
            refilter()
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
            refilter()
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
        // Weak capture only inside the loop body: the `for await` loop suspends at each element,
        // so we MUST NOT promote `self` to a strong reference outside the loop body.
        // A strong reference across suspension == ViewModel never deallocates.
        observationTasks.append(Task { [weak self] in
            guard let stream = await self?.repository.wsConnectionState else { return }
            for await state in stream {
                guard let self else { break }
                await MainActor.run { self.connectionState = state }
            }
        })

        // Live verdict events → VerdictToast
        observationTasks.append(Task { [weak self] in
            guard let stream = await self?.repository.verdictReceived else { return }
            for await submission in stream {
                guard let self else { break }
                await MainActor.run { self.incomingVerdict = submission }
            }
        })

        // Staleness tracking — drives StalenessBanner
        observationTasks.append(Task { [weak self] in
            guard let stream = await self?.repository.dataLastUpdated else { return }
            for await date in stream {
                guard let self else { break }
                await MainActor.run {
                    self.dataLastUpdated = date
                    if let date {
                        self.isDataStale = Date().timeIntervalSince(date) > 300
                    }
                }
            }
        })
    }

    // MARK: - Private Helpers

    private func refilter() {
        let contests = state.contests
        guard !searchQuery.isEmpty else {
            filteredResults = contests.sorted { $0.startTime < $1.startTime }
            return
        }
        filteredResults = contests
            .filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
            .sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - Private

private extension ContestViewModel {
    func errorMessage(from error: Error) -> String {
        (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
}
