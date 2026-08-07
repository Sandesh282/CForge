import Foundation

struct ProblemFilterEngine {
    static func filter(
        problems: [Problem],
        query: String,
        selectedTag: String?,
        ratingRange: RatingRange? = nil
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
        
        let tagFiltered: [Problem]
        if let tag = selectedTag {
            tagFiltered = queryFiltered.filter { problem in
                problem.tags.contains(tag)
            }
        } else {
            tagFiltered = queryFiltered
        }

        guard let ratingRange = ratingRange else {
            return tagFiltered
        }

        return tagFiltered.filter { problem in
            guard let rating = problem.rating else {
                return false
            }

            return ratingRange.contains(rating)
        }
    }
}
