import Foundation
import PushKit
import CallKit
import TwilioVoice
import KeychainAccess

public class VoipNotification: NSObject, Observable1 {
    private struct Key {
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
        public static let deviceToken = "\(bundle).keychain.device.token.key"
    }
    
    private var deviceToken: Data? {
        get {
            try? Keychain(service: Key.keychainName).getData(Key.deviceToken)
        }
        set {
            let keychain = Keychain(service: Key.keychainName)
            if let newValue = newValue {
                try! keychain.synchronizable(true).set(newValue, key: Key.deviceToken)
            } else {
                try! keychain.synchronizable(true).remove(Key.deviceToken)
            }
        }
    }

    private var voipRegistry: PKPushRegistry
    
    weak var notificationHandler: VoipNotificationHandler? {
        didSet {
            if let handler = notificationHandler,
                let pendingData = pendingNotification {
                handler.handleTwilioVoipNotification(pendingData)
            }
        }
    }
    
    private var pendingNotification: [AnyHashable: Any]?
    
    override init() {
        voipRegistry = PKPushRegistry(queue: .main)
        
        super.init()

        voipRegistry.desiredPushTypes = [.voIP]
        
        DispatchQueue.main.async {
            self.voipRegistry.delegate = self
        }
    }
    
    // MARK: - Event
    public enum Event {
        case register(Data)
        case unregister(Data)
    }
    
    public var observerTokenGenerator = 0
    public var observers: [Int: (Event) -> Void] = [:]
    public var initialEvent: Event? {
        didSet {
            guard let initialEvent else { return }
            notifyObservers(initialEvent)
        }
    }
}

extension VoipNotification: PKPushRegistryDelegate {
    
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else {
            return
        }
        deviceToken = pushCredentials.token
        initialEvent = Event.register(pushCredentials.token)
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP,
            let deviceToken = deviceToken else {
                return
        }
        self.deviceToken = nil
        initialEvent = Event.unregister(deviceToken)
    }
    
   
    
    public func pushRegistry(_ registry: PKPushRegistry,
                             didReceiveIncomingPushWith payload: PKPushPayload,
                             for type: PKPushType,
                             completion: @escaping () -> Void
    ) {
        print("VOIP PUSH RECIEVED")
                
        guard type == .voIP else { return }
        
        handleVoIPPush(payload: payload, completion: completion)
    }
    
    private func handleVoIPPush(payload: PKPushPayload, completion: @escaping () -> Void) {
        if CallMagic.provider == nil {
            CallMagic.provider = CallProvider()
        }
        
        if CallMagic.UID != nil {
            CallMagic.UID = UUID()
        }

        if payload.dictionaryPayload["twi_message_type"] != nil {
            handleTwilioVoIPPush(payload: payload, completion: completion)
        } else if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
            handleTelnyxVoIPPush(payload: payload)
            completion()
        }
    }

    private func handleTwilioVoIPPush(payload: PKPushPayload, completion: @escaping () -> Void) {
        guard let twiMessageType = payload.dictionaryPayload["twi_message_type"] as? String else { return }
        switch twiMessageType {
        case "twilio.voice.call":
            if let handler = notificationHandler {
                handler.handleTwilioVoipNotification(payload.dictionaryPayload)
            } else {
                pendingNotification = payload.dictionaryPayload
            }
            
            let twi_from = (payload.dictionaryPayload["twi_from"] as? String) ?? "Connecting.."

            CallMagic.update = CXCallUpdate()
            CallMagic.update?.remoteHandle = CXHandle(type: .generic, value: twi_from)
            CallMagic.update?.supportsDTMF = true
            CallMagic.update?.supportsHolding = false
            CallMagic.update?.supportsGrouping = false
            CallMagic.update?.supportsUngrouping = false
            CallMagic.update?.hasVideo = false
            CallMagic.update?.localizedCallerName = twi_from
               
            if let uid = CallMagic.UID, let provider = CallMagic.provider, let update = CallMagic.update {
                CallMagic.update = nil
                provider.reportIncomingCall(from: uid , with: update) { _ in
                    print("Incoming first reportIncomingCall ok")
                    completion()
                }
            }
        case "twilio.voice.cancel", "twilio.voice.end":
            if let uid = CallMagic.UID , let provider = CallMagic.provider {
                
                if let handler = notificationHandler {
                    handler.handleTwilioVoipNotification(payload.dictionaryPayload)
                } else {
                    pendingNotification = payload.dictionaryPayload
                }
                
                print("Incoming close ok")
                provider.close(from: uid)
            }
        default:
            return
        }
    }
    
    private func handleTelnyxVoIPPush(payload: PKPushPayload) {
        if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
            var callID = UUID.init().uuidString
            if let newCallId = (metadata["call_id"] as? String),
               !newCallId.isEmpty {
                callID = newCallId
            }
            let callerName = (metadata["caller_name"] as? String) ?? ""
            let callerNumber = (metadata["caller_number"] as? String) ?? ""
            
          
            
            let caller = callerName.isEmpty ? (callerNumber.isEmpty ? "Unknown" : callerNumber) : callerName
            let uuid = UUID(uuidString: callID)
//            self.processVoIPNotification(callUUID: uuid!,pushMetaData: metadata)
//            self.newIncomingCall(from: caller, uuid: uuid!)
        } else {
            // If there's no available metadata, let's create the notification with dummy data.
            let uuid = UUID.init()
//            self.processVoIPNotification(callUUID: uuid,pushMetaData: [String: Any]())
//            self.newIncomingCall(from: "Incoming call", uuid: uuid)
        }
    }
}
