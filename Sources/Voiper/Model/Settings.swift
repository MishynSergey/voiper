import Foundation
import KeychainAccess

public class Settings {
    
    public struct Key {
        fileprivate static var bundle: String {
            if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path),
               let bundle = dict["CFBundleIdentifier"] as? String {
                return bundle
            } else {
                fatalError("add callBaseURL -> Info.plist")
            }
        }
        
        public static var keychainName        = "\(bundle).keychain.key"
        public static var userToken           = "\(bundle).keychain.user.token.key"
        public static var deviceId            = "\(bundle).device.id.key"
        public static var restorationDate     = "\(bundle).restoration.date.key"
        public static var hasAccessContact    = "\(bundle).hasAvailable.key"
        public static var pinCodeLockKey      = "\(bundle).pinCodeLockKey.key"
        public static var datePinLockKey      = "\(bundle).datePinLockKey.key"
        public static var lastVisitDateKey    = "\(bundle).lastVisit.key"
    }
    
    // MARK: — deviceId
    
    public static var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: Key.deviceId) {
            return id
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: Key.deviceId)
            return newId
        }
    }
    
    // MARK: — hasAccessContact
    
    public static var hasAccessContact: Bool {
        get {
            UserDefaults.standard.bool(forKey: Key.hasAccessContact)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.hasAccessContact)
        }
    }
    
    public static var userToken: String? {
        get {
            let keychain = Keychain(service: Key.keychainName)
            if let token = keychain[Key.userToken] {
                if UserDefaults.standard.string(forKey: Key.userToken) != token {
                    UserDefaults.standard.set(token, forKey: Key.userToken)
                }
                return token
            }
            if let token = UserDefaults.standard.string(forKey: Key.userToken) {
                try? keychain.synchronizable(true).set(token, key: Key.userToken)
                return token
            }
            return nil
        }
        set {
            let keychain = Keychain(service: Key.keychainName)
            
            if let token = newValue {
                try? keychain.synchronizable(true).set(token, key: Key.userToken)
                UserDefaults.standard.set(token, forKey: Key.userToken)
            } else {
                try? keychain.synchronizable(true).remove(Key.userToken)
                UserDefaults.standard.removeObject(forKey: Key.userToken)
            }
        }
    }
    
    public static var isUserAuthorized: Bool {
        return userToken != nil
    }
    
    private static let restorationInterval: TimeInterval = 60 * 60 * 24 * 2
    
    public var restorationDate: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: Key.restorationDate)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: Key.restorationDate)
        }
    }
    
    public var isRestoringPeriod: Bool {
        guard let date = restorationDate else { return false }
        return Date().timeIntervalSince(date) < Settings.restorationInterval
    }
    
    @UserDefault(key: "isDoNotDisturb", defaultValue: false)
    public static var isDoNotDisturb: Bool?
    
    @UserDefault(key: "isCheckPin", defaultValue: false)
    public static var isCheckPin: Bool?
    
    @UserDefault(key: "isFastReply", defaultValue: false)
    public static var isFastReply: Bool?
    
    @UserDefault(key: "PinCode", defaultValue: "")
    public static var pinCode: String?
    
    @UserDefault(key: "fromDate", defaultValue: nil)
    public static var fromDate: Date?
    
    @UserDefault(key: "toDate", defaultValue: nil)
    public static var toDate: Date?
}


// MARK: — Storage

public class Storage {
    public struct Key {
        static let chatParticipantKey = "\(Settings.Key.bundle).chat.participant.key"
        static let defaultNumberId   = "\(Settings.Key.bundle).defaultNumberId.key"
    }
    
    public static var pendingChatParticipant: String? {
        get {
            UserDefaults.standard.string(forKey: Key.chatParticipantKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.chatParticipantKey)
        }
    }
    
    public static var defaultNumberId: Int? {
        get {
            let v = UserDefaults.standard.integer(forKey: Key.defaultNumberId)
            return v == 0 ? nil : v
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: Key.defaultNumberId)
            } else {
                UserDefaults.standard.removeObject(forKey: Key.defaultNumberId)
            }
            UserDefaults.standard.synchronize()
        }
    }
}

@propertyWrapper
public struct UserDefault<T> {
    private let key: String
    private let defaultValue: T?
    
    public init(key: String, defaultValue: T?) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    public var wrappedValue: T? {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            if let v = newValue {
                UserDefaults.standard.set(v, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
