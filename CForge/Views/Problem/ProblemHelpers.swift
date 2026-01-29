import SwiftUI

extension ProblemListView {
    
    func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case ..<1000: return .gray
        case 1000..<1500: return .green
        case 1500..<2000: return .blue
        default: return .red
        }
    }
}

