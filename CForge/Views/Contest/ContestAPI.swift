import SwiftUI
import Foundation

extension ContestListView {
    
    func loadContests() async {
        do {
            contests = try await fetchContests()
        } catch {
            handleError(error)
        }
    }
    
    func refreshContests() async {
        isRefreshing = true
        do {
            contests = try await fetchContests()
        } catch {
            handleError(error)
        }
        isRefreshing = false
    }
    
    func fetchContests() async throws -> [CFContest] {
        guard let url = URL(string: "https://codeforces.com/api/contest.list") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ContestResponse.self, from: data)
        
        guard response.status == "OK" else {
            throw NSError(domain: "", code: 0, userInfo: [
                NSLocalizedDescriptionKey: response.comment ?? "Unknown error"
            ])
        }
        
        return response.result?.filter { $0.phase == "BEFORE" } ?? []
    }
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
