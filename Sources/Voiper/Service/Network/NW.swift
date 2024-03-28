import Foundation
import PromiseKit
import RealmSwift
import KeychainAccess


public class NW {
    public static let shared = NW()
    private let service = Service.shared
    
    private init () {}
    
    public func getRegion(with regionCode: String, completion: @escaping (Swift.Result<RegionsResponse, Error>) -> Void) {
        let promise: Promise<RegionsResponse> = service.execute(.getRegions(regionCode))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getRegionPhones(country: String, region: String, type: String, completion: @escaping (Swift.Result<RegionNumbersResponse, Error>) -> Void) {
        let promise: Promise<RegionNumbersResponse> = service.execute(.getRegionPhones(country: country, region: region, type: type))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func deletePhoneNumber(with id: Int, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        AccountManager.shared.phoneManager.delete(numberId: id).done { _ in
            EventManager.shared.sendDeleteNumberEvent()
            completion(.success(()))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getCountries(isShowAllCountry: Bool, completion: @escaping (Swift.Result<CountryResponse, Error>) -> Void) {
        let promise: Promise<CountryResponse> = service.execute(.getCountries(showAll: isShowAllCountry))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getCountryPhones(countryCode: String, numberType: String, completion: @escaping (Swift.Result<RegionNumbersResponse, Error>) -> Void) {
        let promise: Promise<RegionNumbersResponse> = service.execute(.getCountryPhones(countryCode, numberType))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getFastPhonesCountry(countryCode: String, completion: @escaping (Swift.Result<RegionNumbersResponse, Error>) -> Void) {
        let promise: Promise<RegionNumbersResponse> = service.execute(.getFastPhonesCountry(country: countryCode))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getFastPhonesCountryRegion(countryCode: String, regionCode: String, completion: @escaping (Swift.Result<RegionNumbersResponse, Error>) -> Void) {
        let promise: Promise<RegionNumbersResponse> = service.execute(.getFastPhonesCountryRegion(country: countryCode, region: regionCode))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    
    public func loadAccount(completion: @escaping (Swift.Result<Account, Error>) -> Void) {
        let loadAccount: Promise<AccountResponse> = service.execute(.getAccount)
        loadAccount.then(on: DispatchQueue.global()) { response -> Promise<Account> in
            let account = response.account
            let realm = try! Realm()
            let objectsToDelete = realm.objects(AccountRealm.self).filter { $0.id != account.id }
            try realm.write {
                realm.delete(objectsToDelete)
                let accountRealm = AccountRealm.create(with: account, token: Settings.userToken!)
                realm.add(accountRealm, update: .all)
            }
            return Promise.value(account)
        }.done { result in
            NotificationCenter.default.post(name: Account.updateNotification, object: nil)
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getNumbers(completion: @escaping (Swift.Result<PhoneNumbersResponse, Error>) -> Void) {
        let promise: Promise<PhoneNumbersResponse> = service.execute(.getNumbers)
        promise.done(on: DispatchQueue.global()) { response in
            let numbers = response.numbers
            let realm = try! Realm()
            try realm.write {
                let ids = numbers.map { $0.id }
                let objectsToDelete = realm.objects(PhoneNumberRealm.self).filter("NOT id IN %@", ids)
                realm.delete(objectsToDelete)
                numbers.forEach {
                    let number = PhoneNumberRealm.create(with: $0)
                    realm.add(number, update: .all)
                }
                completion(.success(response))
            }
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func deleteAccount(completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let promise: Promise<EmptyResponse> = service.execute(.deleteAccount)
        promise.done{ _ in
            let realm = try! Realm()
            try! realm.write {
                realm.deleteAll()
            }
            let keychain = Keychain(service: Settings.Key.keychainName)
            do {
                try keychain.synchronizable(true).removeAll()
            } catch {
                print(error)
            }
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func restoreAccount(receipt: String, completion: @escaping(Swift.Result<Account, Error>) -> Void) {
        let promise: Promise<AccountResponse> = service.execute(.restoreAccount(receipt: receipt))
        promise.then(on: DispatchQueue.global()) { response -> Promise<Account> in
            let account = response.account
            let realm = try! Realm()
            let objectsToDelete = realm.objects(AccountRealm.self).filter { $0.id != account.id }
            try realm.write {
                realm.delete(objectsToDelete)
                let accountRealm = AccountRealm.create(with: account, token: Settings.userToken!)
                realm.add(accountRealm, update: .all)
            }
            return Promise.value(account)
        }.done { result in
            NotificationCenter.default.post(name: Account.updateNotification, object: nil)
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func addPhoneNumber(number: RegionNumber, addressId: Int?, subscriptionId: Int?, completion: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        let promise: Promise<EmptyResponse> = service.execute(.addNumber(number: number, addressId: addressId, subscriptionId: subscriptionId))
        promise.done { _ in
            self.getNumbers { result in
                switch result {
                case .success:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                        EventManager.shared.sendAddNumberEvent()
                        completion?(.success(()))
                    })
                case .failure(let error):
                    completion?(.failure(error))
                }
            }
        }.catch { error in
            completion?(.failure(error))
        }
    }
    
    public func updateLocale(_ locale: String, completion: ((Swift.Result<Void, Error>) -> Void)? = nil) {
        let promise: Promise<EmptyResponse> = service.execute(.updateLocale(locale))
        promise.done { _ in
            completion?(.success(()))
        }.catch { error in
            completion?(.failure(error))
        }
    }
    
    public func updateMute(_ date: Date, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        let str = dateFormatter.string(from: date)
        let promise: Promise<EmptyResponse> = service.execute(.updateMute(str))
        promise.done { _ in
            completion(.success(()))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func remoteActivities(with phoneNumberID: Int) -> Promise<[Activity]> {
        let promise: Promise<ActivitiesResponse> = service.execute(.getActivities(phoneNumberID))
        return promise.then(on: DispatchQueue.global()) { response -> Promise<[Activity]> in
            let activities = response.activities
            let realm = try! Realm()
            try! realm.write {
                activities.forEach({
                    realm.add(ActivityRealm.create(with: $0), update: .all)
                })
            }
            
            return Promise.value(activities)
        }
    }
    
    public func getChatActivitiesCount() {
        
    }
    
    public func registerPush( deviceID: String, token: String, completion: (() -> Void)? = nil) {
        let promise: Promise<EmptyResponse> = service.execute(.registerPush(deviceID, token))
        _ = promise.done { _ in
            completion?()
        }
    }
    
    public func addInAppPurchase(
        receipt: String,
        price: String,
        currency: String,
        completion: @escaping (Swift.Result<Void, Error>) -> Void) {
            let promise: Promise<EmptyResponse> = service.execute(.addInAppPurchase(receipt: receipt, price: price, currency: currency))
            promise.done { _ in
                completion(.success(()))
            }.catch { error in
                completion(.failure(error))
            }
        }
    
    public func addSubscription(
        receipt: String,
        price: String,
        currency: String,
        completion: @escaping (Swift.Result<SubscriptionsResponse, Error>) -> Void) {
            let promise: Promise<SubscriptionsResponse> = service.execute(.addSubscription(receipt: receipt, price: price, currency: currency))
            promise.done { result in
                completion(.success(result))
            }.catch { error in
                completion(.failure(error))
            }
        }
    
    
    public func read(numberID: Int, participant: String, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let promise: Promise<EmptyResponse> = service.execute(.readChat(numberID, participant))
        promise.done { _ in
            completion(.success(()))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func sendMessage(
        numberID: Int,
        participant: String,
        message: String,
        data: [Data]? = nil,
        delay: Int?,
        completion: @escaping (Swift.Result<Void, Error>) -> Void)
    {
        let promise: Promise<SendMessageResponse> = service.execute(.sendMessage(numberID, participant, message, data, delay))
        promise.done { result in
            completion(.success(()))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getCallAccessToken(with phoneNumberID: Int, completion: @escaping (Swift.Result<String, Error>) -> Void) {
        let promise: Promise<TwilioAccessTokenResponse> = service.execute(.getCallAccessToken(phoneNumberID))
        promise.done { result in
            completion(.success(result.token))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getPricing(
        from countryISO: String,
        to toCountryISO: String,
        completion: @escaping (Swift.Result<PricingResponse, Error>) -> Void)
    {
        let promise: Promise<PricingResponse> = service.execute(.getPricing(from: countryISO, to: toCountryISO))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getVoicePricing(
        from numberId: Int,
        to: String,
        completion: @escaping (Swift.Result<VoicePricingResponse, Error>) -> Void)
    {
        let promise: Promise<VoicePricingResponse> = service.execute(.getVoicePricing(numberId: numberId, to: to))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getMessagePricing(with numberID: Int, to participant: String, completion: @escaping (Swift.Result<MessagePricingResponse, Error>) -> Void) {
        let promise: Promise<MessagePricingResponse> = service.execute(.getMessagePricing(numberId: numberID, to: participant))
        promise.done { result in
            completion(.success(result))
        }.catch { error in
            completion(.failure(error))
        }
    }
    
    public func getPhoneActivity(isOpen:Bool, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        let promise: Promise<EmptyResponse> = service.execute(.phoneActivity(isOpen: true))
        promise.done { response in
            completion(.success(()))
        }.catch { error in
            completion(.failure(error))
        }
    }
}

