import Foundation

public enum RatingRange: String, CaseIterable, Identifiable {
    case r800to1000
    case r1000to1200
    case r1200to1400
    case r1400to1800
    case r1800Plus
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .r800to1000:
            return "800-1000"
        case .r1000to1200:
            return "1000-1200"
        case .r1200to1400:
            return "1200-1400"
        case .r1400to1800:
            return "1400-1800"
        case .r1800Plus:
            return "1800+"
        }
    }
    
    public func contains(_ rating: Int) -> Bool {
        switch self {
        case .r800to1000:
            return rating >= 800 && rating < 1000
        case .r1000to1200:
            return rating >= 1000 && rating < 1200
        case .r1200to1400:
            return rating >= 1200 && rating < 1400
        case .r1400to1800:
            return rating >= 1400 && rating < 1800
        case .r1800Plus:
            return rating >= 1800
        }
    }
}
