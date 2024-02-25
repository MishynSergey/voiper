
import RealmSwift
import UIKit

public enum NumberProvider: String, Decodable {
    case twilio
    case telnyx
    case unknown
    
    public init(rawValue: String?) {
        switch rawValue?.lowercased() {
        case "twilio":
            self = .twilio
        case "telnyx":
            self = .telnyx
        default:
            self = .unknown
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = NumberProvider(rawValue: try? container.decode(String.self))
    }
}

public struct PhoneNumber: Decodable {
    
    public enum PhonenumberStatus:String,Decodable {
        case active
        case paused
        case expired
        
        var color:UIColor {
            switch self {
            case .active:
                return #colorLiteral(red: 0.07952629775, green: 0.445935607, blue: 0.9994184375, alpha: 1)
            case .paused:
                return .blue
            case .expired:
                return #colorLiteral(red: 0.9969721437, green: 0.3871706128, blue: 0.103756465, alpha: 1)
            }
        }
    }
    
    public let id: Int
    public let region: String
    public let formattedNumber: String
    public let number: String
    public let inserted: Date
    public let expired: Date?
    public let country: String
    public let capabilities: [Capability]
    public let addressRequired: Int
    public let label: String
    public let renewPrice: Int
    public let billedUntil: Date
    public let autorenew: Bool
    public let status: PhonenumberStatus?
    public let subscription: SubscriptionInfo?
    public let subscriptionID: String?
    let provider: NumberProvider
    
    enum CodingKeys: String, CodingKey {
        case id
        case region
        case formattedNumber =  "number_friendly"
        case number
        case inserted =         "inserted_at"
        case expired =          "expired_at"
        case country
        case capabilities
        case addressRequired =  "address_required"
        case label
        case renewPrice =       "renew_price_cr"
        case billedUntil =      "billed_until"
        case autorenew
        case status
        case subscription
        case subscriptionID
        case provider
    }
    
    public var isActive: Bool {
            
        if self.status == .expired {
            return false
        }
        
        if self.status == .paused {
            return false
        }
        
        if let expired = expired {
            return expired > Date()
        } else {
            return true
        }
    }
}

extension PhoneNumber {
    init(realmObject: PhoneNumberRealm) {
        var capabilities: [Capability] = []
        if let capabilityString = realmObject.capabilities {
            capabilities = capabilityString.components(separatedBy: ",")
                .compactMap { value -> Capability? in
                    return Capability(rawValue: value)
            }
        }
        
        self.init(id: realmObject.id,
                  region: realmObject.region,
                  formattedNumber: realmObject.formattedNumber,
                  number: realmObject.number,
                  inserted: realmObject.inserted,
                  expired: realmObject.expired,
                  country: realmObject.country,
                  capabilities: capabilities,
                  addressRequired: realmObject.addressRequired,
                  label: realmObject.label,
                  renewPrice: realmObject.renewPrice,
                  billedUntil: realmObject.billedUntil,
                  autorenew: realmObject.autorenew,
                  status: PhoneNumber.PhonenumberStatus(rawValue: realmObject.status) ?? .expired  , subscription: nil, subscriptionID: realmObject.subscriptionID,
                  provider: NumberProvider(rawValue: realmObject.numberProvider))
    }
}

public class PhoneNumberRealm: Object {
    
    @objc dynamic var id: Int = -1
    @objc dynamic var region: String = ""
    @objc dynamic var formattedNumber: String = ""
    @objc dynamic var number: String = ""
    @objc dynamic var inserted: Date = Date()
    @objc dynamic var expired: Date?
    @objc dynamic var country: String = ""
    @objc dynamic var addressRequired: Int = 0
    @objc dynamic var capabilities: String? = nil
    @objc dynamic var label: String = ""
    @objc dynamic var renewPrice: Int = 0
    @objc dynamic var billedUntil: Date = Date()
    @objc dynamic var autorenew: Bool = true
    @objc dynamic var status: String = ""
    @objc dynamic var subscriptionID: String? = nil
    @objc dynamic var numberProvider: String = ""
    
    static func create(with phoneNumber: PhoneNumber) -> PhoneNumberRealm {
        let realmObject = PhoneNumberRealm()
        realmObject.id = phoneNumber.id
        realmObject.region = phoneNumber.region
        realmObject.formattedNumber = phoneNumber.formattedNumber
        realmObject.number = phoneNumber.number
        realmObject.inserted = phoneNumber.inserted
        realmObject.expired = phoneNumber.expired
        realmObject.country = phoneNumber.country
        realmObject.addressRequired = phoneNumber.addressRequired
        if phoneNumber.capabilities.count > 0 {
            realmObject.capabilities = phoneNumber.capabilities.reduce("") { result, capability -> String in
                var addition = ""
                if result.count > 0 {
                    addition = ", "
                }
                return result + addition + capability.rawValue
            }
        }
        realmObject.label = phoneNumber.label
        realmObject.renewPrice = phoneNumber.renewPrice
        realmObject.billedUntil = phoneNumber.billedUntil
        realmObject.autorenew = phoneNumber.autorenew
        realmObject.status = phoneNumber.status?.rawValue ?? ""
        realmObject.subscriptionID = phoneNumber.subscription?.productId
        realmObject.numberProvider = phoneNumber.provider.rawValue

        return realmObject
    }
    
    
    public override class func primaryKey() -> String? {
        return "id"
    }
}
