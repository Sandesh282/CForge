//
//  CFProblem.swift
//  CForge
//
//  Created by Sandesh Raj on 29/03/25.
//
import Foundation

struct CFProblem: Identifiable {
    let id = UUID()
    let title: String
    let rating: Int
    let tags: [String]
    let solvedCount: Int
    let timeLimit: String
    let memoryLimit: String
    
    static let sampleData: [CFProblem] = [
        CFProblem(title: "A. Beautiful Matrix",
                 rating: 800,
                 tags: ["implementation"],
                 solvedCount: 25431,
                 timeLimit: "2 seconds",
                 memoryLimit: "256 MB"),
        CFProblem(title: "B. Prime Number",
                 rating: 1100,
                 tags: ["math", "number theory"],
                 solvedCount: 18452,
                 timeLimit: "1 second",
                 memoryLimit: "512 MB")
    ]
}
