//
//  ProfileView.swift
//  CForge
//
//  Created by Sandesh Raj on 29/03/25.
//

import SwiftUI
import SDWebImageSwiftUI
import CryptoKit
struct UserStatusResponse: Codable {
    let status: String
    let result: [API_Submission]
    let comment: String?
}


struct Problem: Codable {
    let contestId: Int
    let index: String
    let name: String
}
struct ProfileView: View {
    @State private var profileData: CodeforcesUser?
    @State private var errorMessage: String?
    @State private var solvedProblemsCount: Int?
    @EnvironmentObject var userManager: UserManager

    var userHandle: String {
        userManager.userHandle
    }
    
    var body: some View {
        ScrollView {
            if let user = profileData {
                VStack(spacing: 20) {
                    profileHeader(user: user)
                    ratingSection(user: user)
                    statsSection(user: user)
                }
                .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else {
                ProgressView("Fetching Profile...")
            }
            
        }
        .navigationTitle("Profile")
        .background(
            LinearGradient(
                colors: [.darkBackground, .darkestBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            fetchProfileData()
            fetchSolvedProblems()
        }
    }
    
    // MARK: - Profile Header (Avatar, Handle, Rank)
    private func profileHeader(user: CodeforcesUser) -> some View {
        HStack(spacing: 16) {

            ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.darkerBackground, .darkBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.neonBlue, .neonPurple],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.neonBlue, .neonPurple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .neonBlue.opacity(0.4), radius: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(user.handle)
                    .font(.title.bold())
                
            Text(user.rank ?? "Unranked")
                .font(.headline)
                .foregroundColor(rankColor(for: user.rank ?? ""))
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    // MARK: - Rating Section
    private func ratingSection(user: CodeforcesUser) -> some View {

        let currentRating = user.rating ?? 0
            let maxRatingValue = user.maxRating ?? 1
            let progressPercentage = Int((Double(currentRating) / Double(maxRatingValue)) * 100)
            
            return VStack(spacing: 12) {
                HStack {
                    Text("Rating:")
                        .font(.headline)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Text("\(currentRating)")
                                   .font(.system(.title3).weight(.bold))
                                   .foregroundStyle(
                                       LinearGradient(
                                           colors: [.neonBlue, .neonPurple],
                                           startPoint: .leading,
                                           endPoint: .trailing
                                       )
                                   )
                        .foregroundColor(rankColor(for: user.rank ?? ""))
                }
                .frame(height: 20)
                
                ProgressView(value: Double(currentRating), total: Double(maxRatingValue)) {
                            
                        } currentValueLabel: {
                            
                        }
                        .progressViewStyle(NeonProgressStyle())
                        .overlay(
                            HStack {
                                Text("\(currentRating)/\(maxRatingValue)")
                                    .font(.caption)
                                Spacer()
                                Text("\(progressPercentage)%")
                                    .font(.caption)
                            }
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, 4)
                            .offset(y: 14)
                        )
                        .frame(height: 20)
            }
            .padding()
            .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.darkerBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                           gradient: Gradient(colors: [
                                               .neonBlue.opacity(0.4),
                                               .neonPurple.opacity(0.4)
                                           ]),
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing
                                       ),
                                       lineWidth: 1
                                )
                        )
                )
            .cornerRadius(12)
    }
    struct NeonProgressStyle: ProgressViewStyle {
        func makeBody(configuration: Configuration) -> some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .frame(height: 8)
                    .foregroundColor(.darkerBackground)
                
                RoundedRectangle(cornerRadius: 4)
                    .frame(
                        width: configuration.fractionCompleted.map { CGFloat($0) * UIScreen.main.bounds.width - 32 },
                        height: 8
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonBlue, .neonPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
        }
    }
    // MARK: - Updated Statistics Section
    private func statsSection(user: CodeforcesUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("User Statistics")
                .font(.headline)
                .foregroundColor(.textSecondary)
            
            HStack(spacing: 10) {
                StatCard(value: "\(solvedProblemsCount ?? 0)", label: "Solved")
                StatCard(value: "\(user.contributions ?? 0)", label: "Contributions")
                StatCard(value: "\(user.rating ?? 0)", label: "Rating")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                   gradient: Gradient(colors: [
                                       .neonBlue.opacity(0.4),
                                       .neonPurple.opacity(0.4)
                                   ]),
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing
                               ),
                               lineWidth: 1
                        )
                )
        )
        .cornerRadius(12)
    }
    private func calculateAccuracy(user: CodeforcesUser) -> String {
        guard let solved = user.solvedProblems,
              let attempted = user.attemptedProblems,
              attempted > 0 else {
            return "N/A"
        }
        let accuracy = (Double(solved) / Double(attempted)) * 100
        return String(format: "%.1f%%", accuracy)
    }

    // MARK: - StatCard View
    struct StatCard: View {
        let value: String
        let label: String
        
        var body: some View {
            VStack {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonBlue, .neonPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.darkerBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                       gradient: Gradient(colors: [
                                           .neonBlue.opacity(0.4),
                                           .neonPurple.opacity(0.4)
                                       ]),
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing
                                   ),
                                   lineWidth: 1
                            )
                    )
            )
            .cornerRadius(12)
        }
    }
    // MARK: - New Recent Activity Section
    private func recentActivitySection() -> some View {
        VStack(alignment: .leading) {
            Text("Recent Activity")
                .font(.headline)
            
            ForEach(0..<4, id: \.self) { _ in
                HStack {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.green)
                    Text("Solved Problem 123A")
                    Spacer()
                    Text("2h ago")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Rank Color Helper
    private func rankColor(for rank: String) -> Color {
        switch rank.lowercased() {
        case let r where r.contains("legendary grandmaster"): return .red
        case let r where r.contains("master"): return .orange
        case let r where r.contains("candidate"): return .purple
        case let r where r.contains("expert"): return .blue
        default: return .green
        }
    }
    
    // MARK: - API Fetch Function
    private func fetchProfileData() {
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

    private func fetchSolvedProblems() {
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
    
}

// MARK: - Data Models
struct CodeforcesUser: Codable {
    let handle: String
    let rank: String?
    let rating: Int?
    let maxRating: Int?
    let contributions: Int?
    let solvedProblems: Int?
    let attemptedProblems: Int?
}
struct CodeforcesProfileResponse: Codable {
    let status: String
    let result: [CodeforcesUser]
}


struct API_Submission: Codable {
    let problem: API_Problem
    let verdict: API_Verdict?
    
    enum API_Verdict: String, Codable {
        case ok = "OK"
        case accepted = "ACCEPTED"
        case wrongAnswer = "WRONG_ANSWER"
        case timeLimitExceeded = "TIME_LIMIT_EXCEEDED"
        case other
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawString = try container.decode(String.self).uppercased()
            
            switch rawString {
            case "OK", "ACCEPTED": self = .ok
            case "WRONG_ANSWER": self = .wrongAnswer
            case "TIME_LIMIT_EXCEEDED": self = .timeLimitExceeded
            default: self = .other
            }
        }
    }
}

struct API_Problem: Codable {
    let contestId: Int
    let index: String
    let name: String
}
// MARK: - Preview
#Preview {
    NavigationStack {
        ProfileView()
    }
}

 
