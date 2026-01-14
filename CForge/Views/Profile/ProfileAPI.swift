import Foundation
import SwiftUI
import CryptoKit
extension ProfileView{
    
    func fetchProfileData() {
        let apiKey = "bbc54b409ba11d643f7df85ba269085450b7f2fc"
        let secret = "5fadac371b0312989b5d285d8581acbefc627c15"
        let methodName = "user.info"
        let time = Int(Date().timeIntervalSince1970)
        let rand = "123456"
        
        let paramString = "apiKey=\(apiKey)&handles=\(userHandle)&time=\(time)"
        let hashInput = "\(rand)/\(methodName)?\(paramString)#\(secret)"
        let hash = SHA512.hash(data: Data(hashInput.utf8)).map { String(format: "%02x", $0) }.joined()
        let apiSig = "\(rand)\(hash)"
        
        let urlString = "https://codeforces.com/api/user.info?handles=\(userHandle)"
        print("Fetching from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    errorMessage = "No data received"
                    return
                }
                
                do {
                    print("Raw JSON Response: ", String(data: data, encoding: .utf8) ?? "Invalid JSON")
                    let decodedResponse = try JSONDecoder().decode(CodeforcesProfileResponse.self, from: data)
                    if let userData = decodedResponse.result.first {
                        self.profileData = userData
                    } else {
                        errorMessage = "No user data found"
                    }
                } catch {
                    errorMessage = "JSON parsing error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func fetchSolvedProblems() {
        let urlString = "https://codeforces.com/api/user.status?handle=\(userHandle)&from=1&count=10000"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Network error:", error)
                    self.errorMessage = "Network error"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                do {
                    
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("API Response:", jsonString.prefix(500))
                    }
                    
                    let response = try JSONDecoder().decode(UserStatusResponse.self, from: data)
                    
                    guard response.status == "OK" else {
                        self.errorMessage = response.comment ?? "API error"
                        return
                    }
                    
                    let solved = Set(response.result
                        .filter { $0.verdict == .ok }
                        .map { "\($0.problem.contestId)\($0.problem.index)" }
                    )
                    
                    print("Successfully counted \(solved.count) solved problems")
                    self.solvedProblemsCount = solved.count
                    
                } catch {
                    print("Decoding failed:", error)
                    self.errorMessage = "Data parsing error"
                }
            }
        }.resume()
    }

    func fetchRatingHistory() {
        let urlString = "https://codeforces.com/api/user.rating?handle=\(userHandle)"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(RatingHistoryResponse.self, from: data)
                DispatchQueue.main.async {
                    self.ratingHistory = response.result.sorted {
                        $0.ratingUpdateTimeSeconds < $1.ratingUpdateTimeSeconds
                    }
                }
            } catch {
                print("Rating history decode error:", error)
            }
        }.resume()
    }

}
