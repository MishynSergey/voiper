

import Foundation

public enum Capability: String, Decodable {
    case sms
    case voice
    case mms
    case fax
    case unknown
    
    var label: String? {
        switch self {
        case .voice:
            return .voice
        case .sms:
            return .sms
        case .mms:
            return .mms
        default:
            return nil
        }
    }
    
    public init(rawValue: String) {
        switch rawValue.lowercased() {
        case "sms":
            self = .sms
        case "voice":
            self = .voice
        case "mms":
            self = .mms
        case "fax":
            self = .fax
        default:
            self = .unknown
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = Capability(rawValue: try container.decode(String.self))
    }
}

extension Capability: CustomStringConvertible {
    public var description: String {
        return self.rawValue
    }
}

fileprivate extension String {
    static var sms: String { "SMS".localized }
    static var mms: String { "MMS".localized }
    static var voice: String { "Voice".localized }
}
