import SwiftUI
import Foundation

struct CFContest: Identifiable {
    let id = UUID()
    let name: String
    let isRated: Bool
    let startTime: Date
    let duration: TimeInterval
    
    var timeRemaining: TimeInterval {
        max(0, startTime.timeIntervalSinceNow)
    }
    
    static let sampleData: [CFContest] = [
        CFContest(name: "Codeforces Round #999",
                 isRated: true,
                 startTime: Date().addingTimeInterval(86400),
                 duration: 9000),
        CFContest(name: "Educational Round 120",
                 isRated: true,
                 startTime: Date().addingTimeInterval(172800),
                 duration: 7200)
    ]
}
