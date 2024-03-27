import Foundation
import PushKit
import CallKit
import TwilioVoice
import KeychainAccess
import FirebaseCrashlytics
import OSLog


public class VoipNotification: NSObject, Observable1 {
    private var voipRegistry: PKPushRegistry
    
    weak var notificationHandler: VoipNotificationHandler? = AccountManager.callFlow {
        didSet {
            if let handler = notificationHandler, let pendingData = pendingNotification {
                if pendingData["twi_message_type"] != nil {
                    do {
                        try handler.handleTwilioVoipNotification(pendingData)
                    } catch {
                        Crashlytics.crashlytics().record(error: error)
                    }
                } else {
//                    do {
//                        try handler.handleTelnyxVoipNotification(pendingData)
//                    } catch {
//                        Crashlytics.crashlytics().record(error: error)
//                    }
                    _ = handler.handleTelnyxVoipNotification(pendingData)
                }
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
        Settings.devicePushToken = pushCredentials.token
        initialEvent = Event.register(pushCredentials.token)
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP,
              let deviceToken = Settings.devicePushToken else {
                return
        }
        Settings.devicePushToken = nil
        initialEvent = Event.unregister(deviceToken)
    }
    
   
    
    public func pushRegistry(_ registry: PKPushRegistry,
                             didReceiveIncomingPushWith payload: PKPushPayload,
                             for type: PKPushType,
                             completion: @escaping () -> Void
    ) {
        VLogger.info("VOIP PUSH RECIEVED")
                
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
        } else {
            handleTelnyxVoIPPush(payload: payload, completion: completion)
        }
    }

    private func handleTwilioVoIPPush(payload: PKPushPayload, completion: @escaping () -> Void) {
        VLogger.info("called \(#function)")
        guard let twiMessageType = payload.dictionaryPayload["twi_message_type"] as? String else { return }
        switch twiMessageType {
        case "twilio.voice.call":
            if let handler = notificationHandler {
                do {
                    try handler.handleTwilioVoipNotification(payload.dictionaryPayload)
                } catch {
                    Crashlytics.crashlytics().record(error: error)
                }
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
                    do {
                        try handler.handleTwilioVoipNotification(payload.dictionaryPayload)
                    } catch {
                        Crashlytics.crashlytics().record(error: error)
                    }
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
    
    private func handleTelnyxVoIPPush(payload: PKPushPayload, completion: @escaping () -> Void) {
        VLogger.info("called \(#function)")
        var caller: String = "Incoming call..."
        var callUUID: UUID = UUID()
        if let metadata = payload.dictionaryPayload["metadata"] as? [String: Any] {
            if let callIDString = metadata["call_id"] as? String, !callIDString.isEmpty, let uuid = UUID(uuidString: callIDString) {
                callUUID = uuid
            }

            let callerName = (metadata["caller_name"] as? String) ?? ""
            let callerNumber = (metadata["caller_number"] as? String) ?? ""

            caller = callerName.isEmpty ? (callerNumber.isEmpty ? "Unknown" : callerNumber) : callerName
        }
        CallMagic.UID = callUUID
        if let handler = notificationHandler {
//            do {
//                try handler.handleTelnyxVoipNotification(payload.dictionaryPayload)
//            } catch {
//                VLogger.error("in \(#function) cathced error: \(error)")
//                Crashlytics.crashlytics().record(error: error)
//            }
            handler.handleTelnyxVoipNotification(payload.dictionaryPayload)
                .done {  _ in }
                .catch { error in
                    VLogger.error("in \(#function) cathced error: \(error)")
                    Crashlytics.crashlytics().record(error: error)
                }
        } else {
            pendingNotification = payload.dictionaryPayload
        }
        newTelnyxIncomingCall(callUUID, from: caller, completion: completion)
    }
    
    private func newTelnyxIncomingCall(_ callUUID: UUID, from: String, completion: @escaping () -> Void) {
        VLogger.info("called \(#function)")
        guard let provider = CallMagic.provider else {
            completion()
            return
        }
        
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .generic, value: from)
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = false
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false
        
        provider.reportIncomingCall(from: callUUID, with: callUpdate) { error in
            if let error {
                VLogger.error("in \(#function) during reportIncomingCall(from:, with:) cathced error: \(error)")
                Crashlytics.crashlytics().record(error: error)
            }
            completion()
        }
    }
}
