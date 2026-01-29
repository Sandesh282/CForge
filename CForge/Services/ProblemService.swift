import Foundation

protocol ProblemServiceProtocol {
    func fetchProblems() async throws -> [ApiProblem]
    func fetchContestSubmissions(contestId: Int, handle: String) async throws -> [Submission]
}

final class ProblemService: ProblemServiceProtocol {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchProblems() async throws -> [ApiProblem] {
        let urlString = "https://codeforces.com/api/problemset.problems"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        AppLog.debug("Fetching problems from \(urlString)", category: .network)
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.transportError(wrapped: NSError(domain: "Invalid Response", code: 0))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            AppLog.error("Server error: \(httpResponse.statusCode)", category: .network)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(ProblemsResponse.self, from: data)
            guard decodedResponse.status == "OK", let result = decodedResponse.result else {
                let message = decodedResponse.comment ?? "Unknown API Error"
                AppLog.error("API Error: \(message)", category: .network)
                throw NetworkError.apiError(message: message)
            }
            return result.problems
        } catch {
            AppLog.error("Decoding error: \(error)", category: .network)
            throw NetworkError.decodingError(wrapped: error)
        }
    }
    
    func fetchContestSubmissions(contestId: Int, handle: String) async throws -> [Submission] {
        let urlString = "https://codeforces.com/api/contest.status?contestId=\(contestId)&handle=\(handle)&from=1&count=50"
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        AppLog.debug("Fetching submissions for contest \(contestId), handle: \(handle)", category: .network)
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.transportError(wrapped: NSError(domain: "Invalid Response", code: 0))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            AppLog.error("Server error: \(httpResponse.statusCode)", category: .network)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let decodedResponse = try JSONDecoder().decode(ContestSubmissionsResponse.self, from: data)
            guard decodedResponse.status == "OK", let result = decodedResponse.result else {
                let message = decodedResponse.comment ?? "Unknown API Error"
                AppLog.error("API Error: \(message)", category: .network)
                throw NetworkError.apiError(message: message)
            }
            return result
        } catch {
             AppLog.error("Decoding error: \(error)", category: .network)
             throw NetworkError.decodingError(wrapped: error)
        }
    }
}
