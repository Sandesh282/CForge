import Foundation
import SwiftUI

struct RatingChange: Codable {
    let contestId: Int
    let contestName: String
    let handle: String
    let rank: Int
    let ratingUpdateTimeSeconds: Int
    let oldRating: Int
    let newRating: Int
}

struct RatingHistoryResponse: Codable {
    let status: String
    let result: [RatingChange]
}
struct UserStatusResponse: Codable {
    let status: String
    let result: [API_Submission]
    let comment: String?
}

struct CodeforcesUser: Codable {
    let handle: String
    let rank: String?
    let rating: Int?
    let maxRating: Int?
    let contribution: Int?
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
