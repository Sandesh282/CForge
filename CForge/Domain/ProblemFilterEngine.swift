import Foundation

struct ProblemFilterEngine {
    static func filter(
        problems: [Problem],
        query: String,
        selectedTag: String?
    ) -> [Problem] {
        
        let queryFiltered: [Problem]
        if query.isEmpty {
            queryFiltered = problems
        } else {
            let lowercasedQuery = query.lowercased()
            queryFiltered = problems.filter { problem in
                let titleMatch = problem.title.lowercased().contains(lowercasedQuery)
                let numberMatch = "\(problem.contestId)\(problem.index)".lowercased().contains(lowercasedQuery)
                
                let ratingMatch: Bool
                if let rating = problem.rating, let _ = Int(query) {
                    ratingMatch = String(rating).contains(query)
                } else {
                    ratingMatch = false
                }
                
                return titleMatch || numberMatch || ratingMatch
            }
        }
        
        guard let tag = selectedTag else {
            return queryFiltered
        }
        
        return queryFiltered.filter { problem in
            problem.tags.contains(tag)
        }
    }
}
