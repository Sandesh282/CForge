
import SwiftUI

extension ProblemListView {
    struct SubmitLauncherView: View {
        let problem: Problem
        @State private var selectedLanguage = "GNU C++20 (64)"
        
        let languages = [
            "GNU C++20 (64)", "GNU C++17", "GNU C++14",
            "Java 21", "Java 17", "Java 11",
            "Python 3", "PyPy 3",
            "C# 10", "C# 8",
            "Kotlin 1.9",
            "Go 1.22",
            "Rust 2021",
            "Node.js 20",
            "Ruby 3",
            "Haskell GHC 9"
        ]
        
        var body: some View {
            VStack(spacing: 24) {
                Spacer()
                
                HStack {
                    Text("Preferred language")
                        .foregroundColor(.textSecondary)
                    Spacer()
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(languages, id: \.self) { language in
                            Text(language).tag(language)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }
                .padding()
                .background(Color.darkerBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Link(destination: submitURL) {
                        HStack {
                            Text("Open Submissions Page")
                                .fontWeight(.bold)
                            Image(systemName: "arrow.up.right.square")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.neonBlue, .neonPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .neonBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Text("You will be redirected to the official Codeforces website to submit using your own account.")
                        .font(.footnote)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .padding()
            .background(Color.darkBackground)
        }
        
        var submitURL: URL {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "codeforces.com"
            components.path = "/contest/\(problem.contestId)/submit"
            components.queryItems = [
                URLQueryItem(name: "problemIndex", value: problem.index)
            ]
            return components.url ?? URL(string: "https://codeforces.com")!
        }
    }
}
