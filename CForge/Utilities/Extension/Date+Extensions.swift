import SwiftUI

extension Date {
    static func fromCodeforcesTimestamp(_ timestamp: TimeInterval) -> Date {
        Date(timeIntervalSince1970: timestamp)
    }
    
    func timeRemainingString() -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: max(0, timeIntervalSinceNow)) ?? "N/A"
    }
}

