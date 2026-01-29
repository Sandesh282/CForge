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
    
    func fetchContestSubmissions(contestId: Int, handle: String) async throws -> [Submission] {
        let urlString = "https://codeforces.com/api/contest.status?contestId=\(contestId)&handle=\(handle)&from=1&count=100" // Fetch last 100 seems reasonable for a single contest
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Bad server response"])
            }
            
            let decodedResponse = try JSONDecoder().decode(ContestSubmissionsResponse.self, from: data)
            
            guard decodedResponse.status == "OK" else {
                throw NSError(domain: "", code: 0, userInfo: [
                    NSLocalizedDescriptionKey: "API Error: \(decodedResponse.comment ?? "Unknown error")"
                ])
            }
            
            return decodedResponse.result ?? []
            
        } catch {
            print("Fetch submissions error:", error.localizedDescription)
            throw error
        }
    }

}

