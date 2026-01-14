import SwiftUI
extension ProfileView{
    func rankColor(for rank: String) -> Color {
        switch rank.lowercased() {
        case let r where r.contains("legendary grandmaster"): return .red
        case let r where r.contains("master"): return .orange
        case let r where r.contains("candidate"): return .purple
        case let r where r.contains("expert"): return .blue
        default: return .green
        }
    }

    func calculateAccuracy(user: CodeforcesUser) -> String {
        guard let solved = user.solvedProblems,
              let attempted = user.attemptedProblems,
              attempted > 0 else {
            return "N/A"
        }
        let accuracy = (Double(solved) / Double(attempted)) * 100
        return String(format: "%.1f%%", accuracy)
    }
}
