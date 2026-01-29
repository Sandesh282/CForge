
import Foundation

extension ProblemListView {
    struct Problem: Identifiable, Codable, Hashable {
        let id: String
        let contestId: Int
        let index: String
        let title: String
        let rating: Int?
        let tags: [String]
    }

    struct ProblemsResponse: Codable {
        let status: String
        let result: ProblemsResult?
        let comment: String?
    }

    struct ProblemsResult: Codable {
        let problems: [ApiProblem]
        let problemStatistics: [ProblemStatistic]
    }

    struct ApiProblem: Codable {
        let contestId: Int?
        let index: String?
        let name: String?
        let rating: Int?
        let tags: [String]?
    }

    struct ProblemStatistic: Codable {
        let contestId: Int?
        let index: String?
        let solvedCount: Int?
    }

    struct ProblemStatementResponse: Codable {
        let status: String
        let result: ProblemStatementResult?
        let comment: String?
    }

    struct ProblemStatementResult: Codable {
        let problem: ProblemStatement
    }

    struct ProblemStatement: Codable {
        let name: String
        let contestId: Int?
        let index: String?
        let rating: Int?
        let tags: [String]?
        let statement: String?
    }
}
