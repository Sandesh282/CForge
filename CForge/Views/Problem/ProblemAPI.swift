import SwiftUI
import Foundation

extension ProblemListView {
    
    func loadProblems() async {
        isLoading = true
        errorMessage = ""
        
        do {
            let problems = try await fetchProblemsFromAPI()
            self.allProblems = problems
            self.filteredProblems = problems
            filterProblems()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    func fetchProblemsFromAPI() async throws -> [Problem] {
        let urlString = "https://codeforces.com/api/problemset.problems"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        do {

            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            

            print("Fetching from:", urlString)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bad server response"])
            }
            

            print("Raw response:", String(data: data, encoding: .utf8) ?? "Invalid data")
            
            let decodedResponse = try JSONDecoder().decode(ProblemsResponse.self, from: data)
            
            guard decodedResponse.status == "OK" else {
                throw NSError(domain: "", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "API Error: \(decodedResponse.comment ?? "Unknown error")"
                ])
            }
            

            return decodedResponse.result?.problems.compactMap { apiProblem in
                guard let contestId = apiProblem.contestId,
                      let index = apiProblem.index,
                      let name = apiProblem.name else {
                    print("Skipping problem with missing fields:", apiProblem)
                    return nil
                }
                
                return Problem(
                    id: "\(contestId)\(index)",
                    contestId: contestId,
                    index: index,
                    title: name,
                    rating: apiProblem.rating,
                    tags: apiProblem.tags ?? []
                )
            } ?? []
            
        } catch {

            print("Fetch error:", error.localizedDescription)
            throw error
        }
    }
}

extension ProblemListView.ProblemDetailView.DescriptionTab {
    func loadProblemStatement() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let statement = try await fetchProblemStatementFromAPI()
            print("Fetched statement:", statement)
            problemStatement = statement
        } catch {
            print("Error fetching problem:", error)
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    func fetchProblemStatementFromAPI() async throws -> String {
        let urlString = "https://codeforces.com/api/problemset.problem?contestId=\(problem.contestId)&index=\(problem.index)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        print("Fetching from:", urlString)
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        print("Raw API response:", json ?? "No data")
        
        guard let result = json?["result"] as? [String: Any],
              let problemData = result["problem"] as? [String: Any] else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
        }
        
        if let content = problemData["description"] as? String {
            return content
        }
        
        return "No problem statement available"
    }
}
