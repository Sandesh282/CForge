import Foundation

enum AppLog {
    enum Category: String {
        case network = "[Network]"
        case cache = "[Cache]"
        case ui = "[UI]"
        case lifecycle = "[Lifecycle]"
        case error = "[ERROR]"
    }
    
    static func debug(_ message: String, category: Category = .ui, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        print("\(category.rawValue) \(message) | \(filename):\(line) - \(function)")
        #endif
    }
    
    static func error(_ message: String, category: Category = .error, file: String = #file, function: String = #function, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        print("\(category.rawValue) ‼️ \(message) | \(filename):\(line) - \(function)")
    }
}
