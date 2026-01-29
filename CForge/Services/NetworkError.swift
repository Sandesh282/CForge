import Foundation

enum NetworkError: LocalizedError, Equatable {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(wrapped: Error)
    case transportError(wrapped: Error)
    case apiError(message: String)
    case noData
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .serverError(let statusCode):
            return "Server returned an error. Status code: \(statusCode)"
        case .decodingError(let error):
            return "Failed to process data from server. Details: \(error.localizedDescription)"
        case .transportError(let error):
            return "Connection failed. Please check your internet connection. Details: \(error.localizedDescription)"
        case .apiError(let message):
            return "Codeforces API Error: \(message)"
        case .noData:
            return "The server returned no data."
        case .unauthorized:
            return "Unauthorized access. Please check your credentials."
        }
    }
    
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.serverError(let l), .serverError(let r)): return l == r
        case (.decodingError, .decodingError): return true 
        case (.transportError, .transportError): return true 
        case (.apiError(let l), .apiError(let r)): return l == r
        case (.noData, .noData): return true
        case (.unauthorized, .unauthorized): return true
        default: return false
        }
    }
}
