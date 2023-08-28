

import PromiseKit
import RealmSwift
import UIKit

public class ChatModel: Observable1 {
    public enum Event {
        case initial, update([Int], [Int], [Int])
    }
    public var observerTokenGenerator: Int = 0
    public var observers: [Int : (Event) -> Void] = [:]
    public var initialEvent: Event? = .initial
    
    static let activityPerPage = 20
    
    public var numberId: Int
    public var participant: String
    public var canMore = true
    
    public var delayed:[DelayedDessages]?
    
    func isDelayedPresent() -> Bool {
        return delayed?.count ?? 0 > 0
    }
    
    public var lastActivity: Activity? {
        return activities.last
    }
    
    private var service: Service
    public unowned var activityModel: ActivityModel
    private let realm: Realm
    private let localActivities: Results<ChatActivityRealm>
    private var token: NotificationToken?
    
    private var activities: [Activity] = []
    
    public var activitiesWithFuture: [Activity] {
        var candidate = self.activities
        
        self.delayed?.sorted(by: { a, b in
            a.will_be_sent_at ?? Date() < b.will_be_sent_at ?? Date()
        }).forEach({ delayed in
            candidate.append(Activity(id: delayed.cancel_id, type: .message, from: "me", to: delayed.to, numberId: 0, participant: delayed.to, status: .accepted, direction: .outbound, read: true, duration: nil, body: delayed.body, images: nil, startedAt: nil, endedAt: nil, sentAt: delayed.will_be_sent_at, insertedAt: delayed.will_be_sent_at))
        })
        
        return candidate
    }
    
    public init(service: Service, activityModel: ActivityModel, numberId: Int, participant: String) {
        self.service = service
        self.numberId = numberId
        self.participant = participant
        self.activityModel = activityModel
        realm = try! Realm()
        localActivities = realm.objects(ChatActivityRealm.self)
            .filter(NSPredicate(format: "numberId == \(numberId) AND participant == %@", participant))
            .sorted(byKeyPath: "insertedAt", ascending: true)
        observChanges()
    }
    
    private func observChanges() {
        token = localActivities.observe { [unowned self] changes in
            switch changes {
            case .initial:
                self.activities = self.localActivities.map { Activity(chatActivity: $0) }
                self.notifyObservers(.initial)
            case .update(_, let deletions, let insertions, let modifications):
                self.activities = self.localActivities.map { Activity(chatActivity: $0) }
                self.notifyObservers(.update(deletions, insertions, modifications))
            default:
                break
            }
        }
    }
    
    deinit {
        token?.invalidate()
    }
    
    public func update(with activity: Activity) {
        if let lastActivity = lastActivity {
            if lastActivity != activity {
                loadNew(to: lastActivity.id)
            }
        } else {
            loadNew()
        }
    }
    
    @discardableResult
    public func loadNew(from startId: Int? = nil, to endId: Int? = nil) -> Promise<Void> {
        let promise: Promise<ActivitiesResponse> = service.execute(.getChatActivities(numberId, participant, startId, ChatModel.activityPerPage))
        return promise.then(on: DispatchQueue.global(), flags: nil) { response -> Promise<Void> in
            let activities = response.activities
            self.delayed = response.delayed_messages
            self.canMore = activities.count == ChatModel.activityPerPage
            let realm = try! Realm()
            try! realm.write {
                activities.forEach({
                    let realmObject = ChatActivityRealm.create(with: $0)
                    realm.add(realmObject, update: .all)
                })
            }
            if let id = endId,
                !activities.contains(where: { $0.id == id }) {
                return self.loadNew(from: activities.max(by: { $0.id > $1.id })?.id, to: id)
            } else {
                return Promise.value(())
            }
            
        }
    }
    
    public func loadMore() -> Promise<Void> {
        guard let last = activities.first,
            canMore else {
                return Promise.value(())
        }
        let promise: Promise<ActivitiesResponse> = service.execute(.getChatActivities(numberId, participant, last.id, ChatModel.activityPerPage))
        return promise.done(on: DispatchQueue.global(), flags: nil) { response in
            self.canMore = response.activities.count == ChatModel.activityPerPage
            let realm = try! Realm()
            try! realm.write {
                response.activities.forEach({
                    let realmObject = ChatActivityRealm.create(with: $0)
                    realm.add(realmObject, update: .all)
                })
            }
        }
    }
    
    public func read() -> Promise<Void> {
        let promise: Promise<EmptyResponse> = service.execute(.readChat(numberId, participant))
        return promise.done { _ in
            self.activityModel.update()
        }
    }
    
    private var tempMessageId = -1
    
    public func send(message: String, delay:Int?) -> Promise<SendMessageResponse> {
        return checkAvailability(phoneNumber: self.participant, action: .sms)
            .then { () -> Promise<SendMessageResponse> in
                let promise: Promise<SendMessageResponse> = self.service.execute(.sendMessage(self.numberId, self.participant, message, nil,delay))
                return promise
            }.then(on: DispatchQueue.global()) { response -> Promise<SendMessageResponse> in
                if let activity = response.activity {
                    let realm = try! Realm()
                    try! realm.write {
                        let realmObject = ChatActivityRealm.create(with: activity)
                        realm.add(realmObject, update: .all)
                    }
                } else {
                    self.loadNew()
                }
                
                self.activityModel.update()
                let promise: Promise<AccountResponse> = self.service.execute(.getAccount)
                return promise.then { [response] _ -> Promise<SendMessageResponse> in
                    return Promise.value(response)
                }
            }
    }
    
    
    public func deleteSheduled(id:Int) -> Promise<Void> {
        return checkAvailability(phoneNumber: self.participant, action: .sms)
            .then { () -> Promise<EmptyResponse> in
                let promise: Promise<EmptyResponse> = self.service.execute(.deteleSheduled(self.numberId, id))
                return promise
            }.then(on: DispatchQueue.global()) { response -> Promise<Void> in
                
                self.loadNew()
                
                self.activityModel.update()
                return Promise.value(())
            }.then { () -> Promise<Void> in
                let promise: Promise<AccountResponse> = self.service.execute(.getAccount)
                return promise.asVoid()
        }
    }
    
    public func send(images: [UIImage],delay:Int?) -> Promise<SendMessageResponse> {
        return checkAvailability(phoneNumber: self.participant, action: .mms)
            .then { () -> Promise<SendMessageResponse> in
                let imagesData = Array(images.compactMap { $0.jpegData(compressionQuality: 0.5) }.prefix(11))
                let promise: Promise<SendMessageResponse> = self.service.executeMultipart(.sendMessage(self.numberId, self.participant, "", [], delay)) { multipartData in
                    imagesData.forEach({ image in
                        multipartData.append(image, withName: "images[]", fileName: "image", mimeType: "image/jpeg")
                    })
                    multipartData.append(self.participant.data(using: .utf8)!, withName: "to")
                    multipartData.append("".data(using: .utf8)!, withName: "text")
                }
                return promise
            }.then(on: DispatchQueue.global()) { response -> Promise<SendMessageResponse> in
                if let activity = response.activity {
                    let realm = try! Realm()
                    try! realm.write {
                        let realmObject = ChatActivityRealm.create(with: activity)
                        realm.add(realmObject, update: .all)
                    }
                } else {
                    self.loadNew()
                }
                
                self.activityModel.update()
                let promise: Promise<AccountResponse> = self.service.execute(.getAccount)
                return promise.then { [response] _ -> Promise<SendMessageResponse> in
                    return Promise.value(response)
                }
        }
    }

    private func checkAvailability(phoneNumber: String, action: VerificationUserManager.Action) -> Promise<Void> {
        return Promise { seal in
            VerificationUserManager.shared.canAction(phoneNumber: phoneNumber, action: action) { result in
                switch result {
                case .success:
                    seal.resolve(nil)
                case .failure(let error):
                    seal.reject(error)
                }
            }
            seal.fulfill(())
        }
    }
    
    private func tempMessage(with text: String) -> ChatActivityRealm {
        let activityRealm = ChatActivityRealm()
        activityRealm.activityId = tempMessageId
        tempMessageId -= 1
        activityRealm.type = Activity.ActivityType.message.rawValue
        activityRealm.from = activityModel.phoneNumber.number
        activityRealm.to = participant
        activityRealm.numberId = activityModel.phoneNumber.id
        activityRealm.participant = participant
        activityRealm.status = Activity.Status.sending.rawValue
        activityRealm.direction = Activity.Direction.outbound.rawValue
        activityRealm.body = text
        activityRealm.sentAt = Date()
        activityRealm.insertedAt = Date()
        
        return activityRealm
    }
}
