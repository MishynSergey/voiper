

import Foundation
import RealmSwift
import PromiseKit
import FirebaseCrashlytics

public class PhoneManager: Observable1 {
    public enum Event {
        case changedActiveModel, update
    }
    
    public typealias ObjectEvent = Event
    public var observerTokenGenerator: Int = 0
    public var observers: [Int : (PhoneManager.Event) -> Void] = [:]
    
    private let service: Service
    public var phoneModels: [PhoneModel] = []
    private let realmPhones: Results<PhoneNumberRealm>
    private var token: NotificationToken?
    
    init(service: Service) {
        self.service = service
        let realm = try! Realm()
        self.realmPhones = realm.objects(PhoneNumberRealm.self)
        addObserver()
    }
    
    private func addObserver() {
        if token == nil {
            token = realmPhones.observe { [weak self] changes in
                guard let self else { return }
                switch changes {
                case .initial, .update:
                    update(with: realmPhones.map { PhoneNumber(realmObject: $0) })
                case .error(let error):
                    Crashlytics.crashlytics().record(error: error)
                    break
                }
            }
        }
    }
    
    deinit {
        token?.invalidate()
    }
    
    func update(with phones: [PhoneNumber]) {
        var models: [PhoneModel] = []
        phones.forEach { phoneNumber in
            if let oldModel = self.phoneModels.first(where: { model in model.phoneNumber.id == phoneNumber.id }) {
                oldModel.phoneNumber = phoneNumber
                models.append(oldModel)
            } else {
                let model = PhoneModel(phoneNumber: phoneNumber, service: self.service)
                model.callManager.voipNotification = AccountManager.shared.voipNotification
                models.append(model)
            }
        }

        phoneModels = models
        
        if let activeID = Storage.defaultNumberId, activeID != 0  {
            phoneModels.forEach { phoneNumber in
                if activeID ==  phoneNumber.phoneNumber.id {
                    self.activePhoneModel = phoneNumber
                }
            }
        }
        if (self.activePhoneModel == nil)  {
            self.activePhoneModel = phoneModels.filter({ $0.phoneNumber.isActive == true }).max(by: { $0.phoneNumber.inserted < $1.phoneNumber.inserted })
        }
        
        if (self.activePhoneModel == nil)  {
            self.activePhoneModel = phoneModels.max(by: { $0.phoneNumber.inserted < $1.phoneNumber.inserted })
        }
        notifyObservers(.update)
    }
    
    public func delete(numberId: Int) -> Promise<Void> {
        let promise: Promise<EmptyResponse> = service.execute(.deleteNumber(id: numberId))
        
        return promise
            .map { [unowned self] _ in
                phoneModels.removeAll(where: { $0.phoneNumber.id == numberId })
                if let activeNumber = phoneModels.first(where: { $0.phoneNumber.status == .active }) {
                    activePhoneModel = activeNumber
                } else {
                    activePhoneModel = phoneModels.first
                }
                let queue = DispatchQueue(label: "realm-subscriptions-queue")
                queue.async {
                    guard
                        let realm = try? Realm(),
                        let objectToDelete = realm.object(ofType: PhoneNumberRealm.self, forPrimaryKey: numberId)
                    else { return }
                    
                    try? realm.write {
                        realm.delete(objectToDelete)
                    }
                }
                return Void()
            }
    }

    public func setActiveNumber(phoneNumber: PhoneModel) {
        self.activePhoneModel = phoneNumber
        EventManager.shared.sendChangeNumberEvents()
    }
    
    
   public var activePhoneModel: PhoneModel? {
        didSet {
            Storage.defaultNumberId = self.activePhoneModel?.phoneNumber.id
            if oldValue?.phoneNumber.id != activePhoneModel?.phoneNumber.id {
                notifyObservers(.changedActiveModel)
            }
            EventManager.shared.sendChangeNumberEvents()
        }
    }
}
