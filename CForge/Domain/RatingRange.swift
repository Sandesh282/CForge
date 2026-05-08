enum RatingRange: String, CaseIterable, Identifiable {
    case r800to1000
    case r1000to1200
    case r1200to1400
    case r1400to1600
    case r1600to1800
    case r1800Plus
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .r800to1000:
            return "800-999"
        case .r1000to1200:
            return "1000-1199"
        case .r1200to1400:
            return "1200-1399"
        case .r1400to1600:
            return "1400-1599"
        case .r1600to1800:
            return "1600-1799"
        case .r1800Plus:
            return "1800+"
        }
    }
    
    func contains(_ rating: Int) -> Bool {
        switch self {
        case .r800to1000:
            return rating >= 800 && rating < 1000
        case .r1000to1200:
            return rating >= 1000 && rating < 1200
        case .r1200to1400:
            return rating >= 1200 && rating < 1400
        case .r1400to1600:
            return rating >= 1400 && rating < 1600
        case .r1600to1800:
            return rating >= 1600 && rating < 1800
        case .r1800Plus:
            return rating >= 1800
        }
    }
}
