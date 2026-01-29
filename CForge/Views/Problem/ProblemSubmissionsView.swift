
import SwiftUI

extension ProblemListView {
    struct ProblemSubmissionsView: View {
        let problem: Problem
        @EnvironmentObject var userManager: UserManager
        @State private var submissions: [Submission] = []
        @State private var isLoading = false
        @State private var errorMessage: String?
        var body: some View {
            VStack {
                if userManager.userHandle.isEmpty {
                    ContentUnavailableView(
                        "Not Signed In",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Sign in to track your progress and see your past attempts.")
                    )
                } else if isLoading {
                    ProgressView("Fetching your attempts...")
                        .tint(.neonBlue)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Error Fetching Data",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Button("Retry") {
                        Task { await loadSubmissions() }
                    }
                    .buttonStyle(.bordered)
                } else if submissions.isEmpty {
                    ContentUnavailableView(
                        "No Attempts Yet",
                        systemImage: "folder.badge.questionmark",
                        description: Text("You haven't submitted any solutions for this problem yet. Give it a shot!")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(submissions) { submission in
                                SubmissionCard(submission: submission)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await loadSubmissions()
                    }
                }
            }
            .task {
                if !userManager.userHandle.isEmpty {
                    await loadSubmissions()
                }
            }
            .background(Color.darkBackground)
        }
        
        private func loadSubmissions() async {
            isLoading = true
            errorMessage = nil
            do {
                
                let handle = userManager.userHandle
                let attempts = try await fetchUserSubmissions(contestId: problem.contestId, handle: handle)
                
                self.submissions = attempts.filter { $0.problem.index == problem.index }
                
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
        
        func fetchUserSubmissions(contestId: Int, handle: String) async throws -> [Submission] {
            let urlString = "https://codeforces.com/api/contest.status?contestId=\(contestId)&handle=\(handle)&from=1&count=50"
            guard let url = URL(string: urlString) else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            }
            
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
        }
    }
    
    struct SubmissionCard: View {
        let submission: Submission
        
        var body: some View {
            HStack(spacing: 16) {
                Rectangle()
                    .fill(submission.verdictColor)
                    .frame(width: 4)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(submission.verdict?.displayName ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(submission.verdictColor)
                    
                    HStack(spacing: 12) {
                        Label {
                            Text(submission.programmingLanguage)
                        } icon: {
                            Image(systemName: "laptopcomputer")
                        }
                        
                        Label {
                            Text(submission.formattedTime)
                        } icon: {
                            Image(systemName: "clock")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Test")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Text(String(format: "%02d", submission.passedTestCount + 1))
                        .font(.custom("Menlo-Bold", size: 16))
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.darkerBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .padding()
            .background(Color.darkerBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [submission.verdictColor.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }
}
