import SwiftUI

extension ProblemListView {
    struct ProblemSubmissionsView: View {
        let problem: Problem
        @EnvironmentObject var userManager: UserManager
        @StateObject private var viewModel = ProblemSubmissionsViewModel()
        
        var body: some View {
            VStack {
                if userManager.userHandle.isEmpty {
                    ContentUnavailableView(
                        "Not Signed In",
                        systemImage: "person.crop.circle.badge.exclamationmark",
                        description: Text("Sign in to track your progress and see your past attempts.")
                    )
                } else {
                    switch viewModel.state {
                    case .loading:
                        ProgressView("Fetching your attempts...")
                            .tint(.neonBlue)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                    case .error(let message):
                        VStack(spacing: 16) {
                            ContentUnavailableView(
                                "Error Fetching Data",
                                systemImage: "exclamationmark.triangle",
                                description: Text(message)
                            )
                            Button("Retry") {
                                Task { await viewModel.loadSubmissions(contestId: problem.contestId, handle: userManager.userHandle) }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                    case .idle:
                        Color.clear.onAppear {
                            Task { await viewModel.loadSubmissions(contestId: problem.contestId, handle: userManager.userHandle) }
                        }
                        
                    case .loaded(let allSubmissions):
                        let problemSubmissions = allSubmissions.filter { $0.problem.index == problem.index }
                        
                        if problemSubmissions.isEmpty {
                            ContentUnavailableView(
                                "No Attempts Yet",
                                systemImage: "folder.badge.questionmark",
                                description: Text("You haven't submitted any solutions for this problem yet. Give it a shot!")
                            )
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(problemSubmissions) { submission in
                                        SubmissionCard(submission: submission)
                                    }
                                }
                                .padding()
                            }
                            .refreshable {
                                await viewModel.loadSubmissions(contestId: problem.contestId, handle: userManager.userHandle)
                            }
                        }
                    }
                }
            }
            .onChange(of: userManager.userHandle) { newHandle in
                if !newHandle.isEmpty {
                    Task { await viewModel.loadSubmissions(contestId: problem.contestId, handle: newHandle) }
                }
            }
            .background(Color.darkBackground)
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
