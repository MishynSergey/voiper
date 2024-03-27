import Foundation
import OSLog

final internal class VLogger {
    
    static func debug(_ message: String) {
        os_log(.error, "VOIPER: %{public}@", message)
    }
    
    static func info(_ message: String) {
        os_log(.error, "VOIPER: %{public}@", message)
    }
    
    static func error(_ message: String) {
        os_log(.error, "VOIPER: %{public}@", message)
    }
}



//@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
//public static let `default`: OSLogType
//
//@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
//public static let fault: OSLogType
