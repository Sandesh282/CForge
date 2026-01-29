import SwiftUI
import Combine

@MainActor
final class ProblemListViewModel: ObservableObject {
    
    enum ViewState {
        case idle
        case loading
        case loaded([Problem])
        case error(String)
    }
    
    @Published private(set) var state: ViewState = .idle
    @Published private(set) var filteredProblems: [Problem] = []
    private let repository: ProblemRepository
    private var allProblems: [Problem] = []
    private var filterTask: Task<Void, Never>?
    
    init(repository: ProblemRepository = ProblemRepository()) {
        self.repository = repository
    }
    
    func loadProblems(forceRefresh: Bool = false) async {
        if case .loading = state { return }
        
        state = .loading
        AppLog.debug("ViewModel: Loading problems (Force: \(forceRefresh))", category: .ui)
        
        do {
            let problems = try await repository.getProblems(forceRefresh: forceRefresh)
            self.allProblems = problems
            self.state = .loaded(problems)
            AppLog.debug("ViewModel: Problems loaded successfully. Count: \(problems.count)", category: .ui)
            
            self.filteredProblems = problems
            
        } catch {
            let message: String
            if let netError = error as? NetworkError {
                message = netError.errorDescription ?? "Unknown network error"
            } else {
                message = error.localizedDescription
            }
            
            AppLog.error("ViewModel: Load Error - \(message)", category: .ui)
            state = .error(message)
        }
    }
    
    func filterProblems(query: String, tag: String?) {
        filterTask?.cancel()
        
        let sourceProblems = allProblems
        
        filterTask = Task.detached(priority: .userInitiated) { [weak self] in
            let filtered = ProblemFilterEngine.filter(
                problems: sourceProblems,
                query: query,
                selectedTag: tag
            )
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                self?.filteredProblems = filtered
                AppLog.debug("ViewModel: Filter applied. Count: \(filtered.count)", category: .ui)
            }
        }
    }
}
