

import Foundation
import RealmSwift

public class Account: Decodable {
    
    public static let updateNotification = Notification.Name("accountUpdateNotification")
    public var hasSubscription = false
    public var balance = 0
    var locale = "en_US"
    
    public let id: Int
    public var paused = false
    public let lastSignIn: Date?
    public let insertedAt: Date?
    public let notificationsCheckin: Bool
    
    public init(id: Int,
                paused: Bool = false,
                lastSignIn: Date? = nil,
                insertedAt: Date? = nil,
                notificationsCheckin: Bool
    ) {
        self.id = id
        self.lastSignIn = lastSignIn
        self.insertedAt = insertedAt
        self.paused = paused
        self.notificationsCheckin = notificationsCheckin
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case hasSubscription = "subscription_active"
        case balance
        case locale
        case lastSignIn = "last_signin_at"
        case insertedAt = "inserted_at"
        case notificationsCheckin = "notifications_checkin"
    }
}

extension Account: CustomStringConvertible {
    public var description: String {
        return jsonFormatDescription((name: "id", value: String(id)),
                                     (name: "paused", value: String(paused)),
                                     (name: "hasSubscription", value: String(hasSubscription)),
                                     (name: "balance", value: String(balance)),
                                     (name: "locale", value: locale),
                                     (name: "lastSignIn", value: lastSignIn?.description ?? ""),
                                     (name: "insertedAt", value: insertedAt?.description ?? ""))
    }
}

public extension Account {
    convenience init(realmObject: AccountRealm) {
        self.init(id: realmObject.id,
                  paused: realmObject.paused,
                  lastSignIn: realmObject.lastSignIn,
                  insertedAt: realmObject.insertedAt,
                  notificationsCheckin: realmObject.notificationsCheckin)
        self.hasSubscription = realmObject.hasSubscription
        self.balance = realmObject.balance
        self.locale = realmObject.locale
    }
}

@objcMembers public class AccountRealm: Object {
    @objc dynamic var token: String = ""
    @objc dynamic var hasSubscription = false
    @objc dynamic var balance: Int = 0
    @objc dynamic var locale = "en_US"
    @objc dynamic var id: Int = -1
    @objc dynamic var paused: Bool = false
    @objc dynamic var lastSignIn: Date? = nil
    @objc dynamic var insertedAt: Date? = nil
    @objc dynamic var notificationsCheckin: Bool = true
    
    
    static func create(with account: Account, token: String) -> AccountRealm {
        let realmObject = AccountRealm()
        realmObject.token = token
        realmObject.id = account.id
        realmObject.paused = account.paused
        realmObject.hasSubscription = account.hasSubscription
        realmObject.balance = account.balance
        realmObject.locale = account.locale
        realmObject.lastSignIn = account.lastSignIn
        realmObject.notificationsCheckin = account.notificationsCheckin
        return realmObject
    }
    
    
    public override class func primaryKey() -> String? {
        return "token"
    }
}
