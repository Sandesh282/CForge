import SwiftUI

extension ProblemListView {
    func filterProblems() {
        var results = allProblems
        
        if let rating = Int(searchText) {
            results = results.filter { $0.rating == rating }
        }
        
        else if !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                results = results.filter {
                    $0.title.lowercased().contains(searchLower) ||
                    $0.tags.contains { $0.lowercased().contains(searchLower) } ||
                    "\($0.contestId)".contains(searchText) ||
                    $0.index.lowercased().contains(searchLower)
                }
            }
        

        if let selectedTag {
            results = results.filter { $0.tags.contains(selectedTag) }
        }
        
        filteredProblems = results
    }
    
    func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case ..<1000: return .gray
        case 1000..<1500: return .green
        case 1500..<2000: return .blue
        default: return .red
        }
    }
}

extension ProblemListView.ProblemDetailView.DescriptionTab {
    func htmlToPlainText(_ html: String) -> String {
            
            return html
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&[^;]+;", with: "", options: .regularExpression)
        }
}
