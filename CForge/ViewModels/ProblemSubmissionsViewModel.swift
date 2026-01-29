import SwiftUI

@MainActor
final class ProblemSubmissionsViewModel: ObservableObject {
    
    enum ViewState {
        case idle
        case loading
        case loaded([Submission])
        case error(String)
    }
    
    @Published private(set) var state: ViewState = .idle
    private let repository: ProblemRepository
    
    init(repository: ProblemRepository = ProblemRepository()) {
        self.repository = repository
    }
    
    func loadSubmissions(contestId: Int, handle: String) async {
        state = .loading
        AppLog.debug("SubmissionsVM: Fetching for \(handle) in contest \(contestId)", category: .ui)
        
        do {
            let submissions = try await repository.getContestSubmissions(contestId: contestId, handle: handle)
            self.state = .loaded(submissions)
            AppLog.debug("SubmissionsVM: Loaded \(submissions.count) submissions", category: .ui)
        } catch {
            let message: String
            if let netError = error as? NetworkError {
                message = netError.errorDescription ?? "Unknown network error"
            } else {
                message = error.localizedDescription
            }
            AppLog.error("SubmissionsVM: Error - \(message)", category: .ui)
            state = .error(message)
        }
    }
}
