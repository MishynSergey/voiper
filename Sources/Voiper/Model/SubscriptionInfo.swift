

import Foundation
import RealmSwift

public struct SubscriptionInfo: Decodable {
    public let id: Int
    public let productId: String
    public let refunded: Bool
    public let cancelled: Bool
    public let purchaseDate: Date
    public let expiresDate: Date
    public let expiredAt: Date?
    public let bundle: String
    public let priceGroup: String?
    public var accountNumberId: Int?
    public var subscriptionGroup: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, refunded, cancelled, bundle
        case productId = "product_id"
        case purchaseDate = "purchase_date"
        case expiresDate = "expires_date"
        case expiredAt = "expired_at"
        case priceGroup = "price_group"
        case accountNumberId = "account_number_id"
        case subscriptionGroup = "subscr_group"
    }
    
}

extension SubscriptionInfo {
    public init(realmObject: SubscriptionInfoRealm) {
        self.init(id: realmObject.id,
                  productId: realmObject.productId,
                  refunded: realmObject.refunded,
                  cancelled: realmObject.cancelled,
                  purchaseDate: realmObject.purchaseDate,
                  expiresDate: realmObject.expiresDate,
                  expiredAt: realmObject.expiredAt,
                  bundle: realmObject.bundle,
                  priceGroup: realmObject.priceGroup,
                  accountNumberId: realmObject.accountNumberId,
                  subscriptionGroup: realmObject.subscriptionGroup)
        self.accountNumberId = realmObject.accountNumberId == -1 ? nil : realmObject.accountNumberId
    }
}

public class SubscriptionInfoRealm: Object {
    @objc public dynamic var id: Int = -1
    @objc public dynamic var productId: String = ""
    @objc public dynamic var refunded: Bool = false
    @objc public dynamic var cancelled: Bool = false
    @objc public dynamic var purchaseDate: Date = Date()
    @objc public dynamic var expiresDate: Date = Date()
    @objc public dynamic var expiredAt: Date?
    @objc public dynamic var bundle: String = ""
    @objc public dynamic var priceGroup: String = ""
    @objc public dynamic var accountNumberId: Int = -1
    @objc public dynamic var subscriptionGroup: Int = -1
    
    
    static func create(with subscriptionInfo: SubscriptionInfo) -> SubscriptionInfoRealm {
        let realmObject = SubscriptionInfoRealm()
        realmObject.id = subscriptionInfo.id
        realmObject.productId = subscriptionInfo.productId
        realmObject.refunded = subscriptionInfo.refunded
        realmObject.cancelled = subscriptionInfo.cancelled
        realmObject.purchaseDate = subscriptionInfo.purchaseDate
        realmObject.expiresDate = subscriptionInfo.expiresDate
        realmObject.expiredAt = subscriptionInfo.expiredAt
        realmObject.bundle = subscriptionInfo.bundle
        realmObject.priceGroup = subscriptionInfo.priceGroup ?? ""
        realmObject.accountNumberId = subscriptionInfo.accountNumberId ?? -1
        realmObject.subscriptionGroup = subscriptionInfo.subscriptionGroup ?? -1
        return realmObject
    }
    
    
    public override class func primaryKey() -> String? {
        return "id"
    }
}


