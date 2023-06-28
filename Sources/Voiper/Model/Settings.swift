

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
        
        public static let keychainName = "\(bundle).keychain.key"
        public static let userToken = "\(bundle).keychain.user.token.key"
        public static let deviceId = "\(bundle).device.id.key"
        public static let restorationDate = "\(bundle).restoration.date.key"
        public static let hasAccessContact = "\(bundle).hasAvailable.key"
        public static let pinCodeLockKey = "\(bundle).pinCodeLockKey.key"
        public static let datePinLockKey = "\(bundle).datePinLockKey.key"
        public static let lastVisitDateKey =  "\(bundle).lastVisit.key"
    }
    
    static var deviceId: String {
        if let deviceId = UserDefaults.standard.string(forKey: Key.deviceId) {
            return deviceId
        } else {
            let deviceId = NSUUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: Key.deviceId)
            return deviceId
        }
    }
    
    public static var hasAccessContact: Bool {
        get {
            let hasAccessContact = UserDefaults.standard.bool(forKey: Key.hasAccessContact)
            return hasAccessContact
        }
        set {
            if newValue != hasAccessContact, newValue {
            }
            UserDefaults.standard.set(newValue, forKey: Key.hasAccessContact)
        }
    }
    
    public static var isUserAuthorized: Bool {
        return userToken != nil
    }
    
    public static var userToken: String? {
        get {
            let keychain = Keychain(service: Key.keychainName)
//            return keychain[Key.userToken]
            return "AdoRQi72EgJHlvmb46w65xn3"
//            return nil
        }
        set {
            let keychain = Keychain(service: Key.keychainName)
            if let newValue = newValue {
                try! keychain.synchronizable(true).set(newValue, key: Key.userToken)
            } else {
                try! keychain.synchronizable(true).remove(Key.userToken)
            }
        }
    }
    
    
    static let restorationInterval: TimeInterval = 60 * 60 * 24 * 2
    var restorationDate: Date? {
        get {
            let dateTime = UserDefaults.standard.double(forKey: Key.restorationDate)
            if dateTime != 0 {
                return Date(timeIntervalSince1970: dateTime)
            } else {
                return nil
            }
        }
        set {
            UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: Key.restorationDate)
        }
    }
    var isRestoringPeriod: Bool {
        if let restorationDate = restorationDate {
            return Date().timeIntervalSince(restorationDate) < Settings.restorationInterval
        } else {
            return false
        }
    }
}

public class Storage {
    public struct Key {
        static let chatParticipantKey = "\(Settings.Key.bundle).chat.participant.key"
        static let defaultNumberId = "\(Settings.Key.bundle).defaultNumberId.key"
    }
    
    public static var pendingChatParticipant: String? {
        set {
            UserDefaults.standard.set(newValue, forKey: Key.chatParticipantKey)
        }
        get {
            return UserDefaults.standard.string(forKey: Key.chatParticipantKey)
        }
    }
    
    public static var defaultNumberId: Int? {
        set {
            if let n = newValue{
                UserDefaults.standard.set( NSInteger(n), forKey: Key.defaultNumberId)
            } else {
                UserDefaults.standard.removeObject(forKey: Key.defaultNumberId)
            }
            UserDefaults.standard.synchronize()
        }
        get {
            return UserDefaults.standard.integer(forKey: Key.defaultNumberId)
        }
    }
}
