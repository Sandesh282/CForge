import Foundation

actor ProblemRepository {
    private let service: ProblemServiceProtocol
    
    private var cachedProblems: [Problem]?
    private var lastFetchTime: Date?
    private let cacheTTL: TimeInterval = 600
    
    private var ongoingProblemsTask: Task<[Problem], Error>?
    
    init(service: ProblemServiceProtocol = ProblemService()) {
        self.service = service
    }
    
    func getProblems(forceRefresh: Bool = false) async throws -> [Problem] {
        if !forceRefresh, let cached = cachedProblems, let lastFetch = lastFetchTime {
            if Date().timeIntervalSince(lastFetch) < cacheTTL {
                AppLog.debug("Returning problems from cache", category: .cache)
                return cached
            } else {
                AppLog.debug("Cache expired. Fetching fresh data.", category: .cache)
            }
        }
        
        if let existingTask = ongoingProblemsTask {
            AppLog.debug("Joining ongoing problems fetch task", category: .network)
            return try await existingTask.value
        }
        
        let task = Task<[Problem], Error> {
            do {
                let apiProblems = try await service.fetchProblems()
                
                let domainProblems = apiProblems.compactMap { apiProblem -> Problem? in
                    guard let contestId = apiProblem.contestId,
                          let index = apiProblem.index,
                          let name = apiProblem.name,
                          let tags = apiProblem.tags else {
                        return nil
                    }
                    
                    return Problem(
                        id: "\(contestId)\(index)",
                        contestId: contestId,
                        index: index,
                        title: name,
                        rating: apiProblem.rating,
                        tags: tags
                    )
                }
                
                self.cachedProblems = domainProblems
                self.lastFetchTime = Date()
                self.ongoingProblemsTask = nil
                
                return domainProblems
            } catch {
                self.ongoingProblemsTask = nil
                throw error
            }
        }
        
        ongoingProblemsTask = task
        return try await task.value
    }
    
    // MARK: - Submissions (Orchestration only, no persistent cache for now per requirements)
    
    func getContestSubmissions(contestId: Int, handle: String) async throws -> [Submission] {

        // Submissions are currently fetched on-demand.
        // Caching can be added later if this becomes a bottleneck.
        
        return try await service.fetchContestSubmissions(contestId: contestId, handle: handle)
    }
}
