import Foundation
import Alamofire

public enum API {
    enum HTTPMethod: CustomStringConvertible {
        case get, post, patch, delete, put
        
        var description: String {
            switch self {
            case .post:
                return "post"
            case .get:
                return "get"
            case .patch:
                return "patch"
            case .delete:
                return "delete"
            case .put:
                return "put"
            }
        }
    }
    
    case getCountries(showAll: Bool)
    case getRegions(String)
    case getCountryPhones(String, String)
    case getRegionPhones(country: String, region: String, type: String)
    case registerPush(String, String)
    case getFastPhonesCountry(country: String)
    case getFastPhonesCountryRegion(country: String,region:String)

    case createAccount
    case restoreAccount(receipt: String)
    case getAccount
    case deleteAccount
    case addSubscription(receipt: String, price: String, currency: String)
    case getSubscriptions
    case addInAppPurchase(receipt: String, price: String, currency: String)
    case addAddress(customerName: String, country: String, city: String, region: String, street: String, postalCode: String)
    case addNumber(number: RegionNumber, addressId: Int?, subscriptionId: Int?)
    case addLocalNumber(number: RegionNumber, subscriptionId: Int)
    case getNumbers
    case lockNumber(number:String)
    case updateNumber(id: Int, label: String?, autorenew: Bool?, recordingEnabled: Bool?)
    case deleteNumber(id: Int)
    case renewNumber(id: Int)
    case getNumberRestorationPeriod(Int)
    case updateLocale(String)
    case updateMute(String)
    
    case updateRing(String?)
    case updateNotif(String?)
    case deteleSheduled(Int,Int)
    
    case numberRepurchase(Int)
    case getTransactions(Int,Int?)
    case getActivities(Int)
    case getChatActivities(Int, String, Int?, Int?)
    case getChatActivitiesCount(Int, String, Int)
    case readChat(Int, String)
    case sendMessage(Int, String, String?, [Data]?, Int?)
    case getCallAccessToken(Int)
    
    case getSubscriptionText
    case getTerms
    
    case getPricing(from: String, to: String)
    case getVoicePricing(numberId: Int, to: String)
    case getMessagePricing(numberId: Int, to: String)
    
    case phoneActivity(isOpen:Bool)
}

extension API {
    var endpoint: String {
        switch self {
        case .getCountries(_):                                              return "countries"
        case .getRegions(let country):                                      return "countries/\(country)/regions"
        case .getCountryPhones(let country, let type):                      return "countries/\(country)/numbers/\(type)"
        case .getRegionPhones(let country, let region, let type):                           return "countries/\(country)/regions/\(region)/numbers/\(type)"
            
        case .getFastPhonesCountry(let country):                            return "pool_numbers/\(country)/Local"
        case .getFastPhonesCountryRegion(let country, let region):          return "pool_numbers/\(country)/regions/\(region)/Local"
        
        case .registerPush:                                                 return "account/devices"
        case .updateRing, .updateNotif:                                     return "account"
        case .createAccount,
             .getAccount,
             .deleteAccount,
             .updateLocale,
             .updateMute:                                                 return "account"
        case .restoreAccount:                                               return "account/subscriptions/restore"
        case .addSubscription,
             .getSubscriptions:                                             return "account/subscriptions"
        case .addInAppPurchase:                                             return "account/in_app_purchases"
        case .addAddress:                                                   return "account/addresses"
        case .addNumber,
             .addLocalNumber,
             .getNumbers:                                                   return "account/numbers"
        case .updateNumber(let id, _, _, _),
             .deleteNumber(let id):                                         return "account/numbers/\(id)"
        case .renewNumber(let id):                                          return "account/numbers/\(id)/renew"
        case .getNumberRestorationPeriod(let id):                           return "account/numbers/\(id)/expired"
        case .numberRepurchase(let id):                                     return "account/numbers/\(id)/repurchase"
        case .getTransactions(let numberId, _):                             return "account/numbers/\(numberId)/transactions"
        case .getActivities(let numberId):                                  return "account/numbers/\(numberId)/activity"
        case .getChatActivities(let numberId, let participant, _, _):       return "account/numbers/\(numberId)/activity/\(participant)"
        case .getChatActivitiesCount(let numberId, let participant, _):     return "account/numbers/\(numberId)/activity/\(participant)/count"
        case .readChat(let numberId, let participant):                      return "account/numbers/\(numberId)/activity/\(participant)/read"
        case .sendMessage(let numberId,_,_,_,_):                             return "account/numbers/\(numberId)/messages"
            
        case .deteleSheduled(let numberId, let id):                         return "account/numbers/\(numberId)/messages/\(id)/cancel"
        case .getCallAccessToken(let numberId):                             return "account/numbers/\(numberId)/access_token"
        case .getSubscriptionText:                                          return "texts/subscription_info"
        case .getTerms:                                                     return "texts/terms_of_use"
        case .getPricing(_, _):                                             return "pricing"
        case .getVoicePricing(let numberId, _):                             return "account/numbers/\(numberId)/pricing/voice"
        case .getMessagePricing(let numberId, _):                           return "account/numbers/\(numberId)/pricing/message"
        case .lockNumber(_):                                                return "numbers/lock"
        case .phoneActivity(_):                                    return "account/event"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getCountries, .getRegions, .getCountryPhones, .getRegionPhones, .getNumbers, .getAccount, .getTransactions,
             .getActivities, .getChatActivities, .getChatActivitiesCount, .getCallAccessToken,
             .getSubscriptions, .getNumberRestorationPeriod, .getPricing, .getVoicePricing, .getMessagePricing,
             .getFastPhonesCountry, .getFastPhonesCountryRegion:
            return HTTPMethod.get
        case .registerPush, .createAccount, .addSubscription, .addInAppPurchase, .addAddress, .addNumber, .addLocalNumber, .renewNumber, .sendMessage,
                .restoreAccount, .getSubscriptionText, .numberRepurchase, .getTerms, .deteleSheduled, .lockNumber, .phoneActivity:
            return HTTPMethod.post
        case .readChat:
            return HTTPMethod.patch
        case .deleteAccount, .deleteNumber:
            return HTTPMethod.delete
        case .updateLocale, .updateNumber, .updateMute, .updateRing, .updateNotif:
            return HTTPMethod.put
        }
    }
    
    var parameters: [String: Any] {
        switch self {
        case .getCountries(let showAll):
            return [
                "show_all": String(showAll)
            ]
        case .registerPush(let deviceId, let tokenId):
            return [
                "device_id": deviceId,
                "push_token": tokenId,
                "bundle": Bundle.main.bundleIdentifier!
            ]
        case .addSubscription(let receipt, let price, let currency):
            return [
                "bundle": Bundle.main.bundleIdentifier!,
                "receipt": receipt,
                "price": price,
                "currency": currency
                ]
        case .addInAppPurchase(let receipt, let price, let currency):
            return [
                "bundle": Bundle.main.bundleIdentifier!,
                "receipt": receipt,
                "price": price,
                "currency": currency
            ]
        case .restoreAccount(let receipt):
            return [
                "bundle": Bundle.main.bundleIdentifier!,
                "receipt": receipt
            ]
        case .addAddress(let customerName, let country, let city, let region, let street, let postalCode):
            return [
                "address": [
                    "customer_name": customerName,
                    "country": country,
                    "city": city,
                    "region": region,
                    "street": street,
                    "postal_code": postalCode
                ]
            ]
        case .addNumber(let phone, let addressId, let subscriptionId):
            var params: [String: Any] = [
                "number": phone.number,
                "country": phone.country,
                "type": "Local"
            ]
            if let region = phone.region {
                params["region"] = region
            }
            if let addressId = addressId {
                params["account_address_id"] = addressId
            }
            if let subscriptionId = subscriptionId {
                params["subscription_id"] = subscriptionId
            }
            return params
        case .addLocalNumber(let phone, let subscriptionId):
            var params: [String: Any] = [
                "number" : phone.number,
                "country" : phone.country,
                "type" : "Local",
                "subscription_id" : subscriptionId
            ]
            if let region = phone.region {
                params["region"] = region
            }
            return params
        case .updateNumber(_, let label, let autorenew, let recordingEnabled):
            var params = [String: Any]()
            if let label = label {
                params["label"] = label
            }
            if let autorenew = autorenew {
                params["autorenew"] = String(autorenew)
            }
            if let recordingEnabled = recordingEnabled {
                params["recording_enabled"] = String(recordingEnabled)
            }
            return ["number": params]
        case .updateLocale(let locale):
            return [
                "account": [
                    "locale": locale
                ]
            ]
            
        case .updateMute(let date):
            return [
                "account": [
                    "notifications_muted_until": date
                ]
            ]
        case .updateRing(let name):
            return [
                "account": [
                    "sound_call": name
                ]
            ]
        case .updateNotif(let name):
            return [
                "account": [
                    "sound_notification": name
                ]
            ]
            
        case .getChatActivities(_, _, let lastId, let perPage):
            var params = [String: Int]()
            if let lastId = lastId {
                params["last_id"] = lastId
            }
            if let perPage = perPage {
                params["per_page"] = perPage
            }
            return params
        case .getChatActivitiesCount(_, _, let lastId):
            return ["last_id": lastId]
        case .sendMessage(_, let to, let text, let images,let delay):
            var param: [String: Any] = ["to": to]
            if let text = text {
                param["text"] = text
            }
            if let images = images {
                param["images"] = images
            }
            if let delay = delay {
                param["delay_sec"] = delay
            }
            return param
        case .getSubscriptionText, .getTerms:
            return ["subscriptions": []]
        case .getPricing(let from, let to):
            return [
                "from": from,
                "to": to
            ]
        case .lockNumber(let number):
            return [
                "number": number
            ]
        case .phoneActivity(let isOpen):
            return [
                "type": isOpen ? "APP_ACTIVE" : "APP_CLOSED"
            ]
        case .getVoicePricing(_, let to), .getMessagePricing(_, let to):
            return [
                "to": to
            ]
        case .getTransactions(_, let last_id):
            if let last_id = last_id {
                return ["last_id":last_id, "per_page":10]
            } else {
                return ["per_page":10]
            }
        default:
            return [:]
        }
    }
    
    var shouldAuthorize: Bool {
        switch self {
        case .getCountries, .getRegions, .getCountryPhones, .getRegionPhones,
                .createAccount, .restoreAccount, .getSubscriptionText, .getTerms,
                .getFastPhonesCountry,.getFastPhonesCountryRegion, .lockNumber:
            return false
        default:
            return true
        }
    }
    
    var headers: HTTPHeaders {
        switch self {
        case .sendMessage(_, _, _, let images,_):
            if images != nil {
                return ["Content-Type": "multipart/form-data"]
            } else {
                return [:]
            }
        default:
            return [:]
        }
    }
}

extension API: CustomStringConvertible {
    public var description: String {
        return " \(method.description.capitalized) \(endpoint)\n\(parameters.description)"
    }
}
