//
//  CFUser.swift
//  CForge
//
//  Created by Sandesh Raj on 30/03/25.
//

import Foundation

struct CFUser {
    let handle: String
    let rating: Int
    let maxRating: Int
    let rank: String
    let contributions: Int
    let solvedProblems: Int
    
    static let sampleData = CFUser(
        handle: "tourist",
        rating: 3828,
        maxRating: 3979,
        rank: "Legendary Grandmaster",
        contributions: 214,
        solvedProblems: 6543
    )
}
