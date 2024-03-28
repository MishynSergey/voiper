import Foundation
import PushKit
import CallKit
import TwilioVoice

public class VoipNotification: NSObject, Observable1 {
    
    private var deviceToken: Data?
    private var voipRegistry: PKPushRegistry
    
    weak var notificationHandler: VoipNotificationHandler? {
        didSet {
            if let handler = notificationHandler,
                let pendingData = pendingNotification {
                handler.handleVoipNotification(pendingData)
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
    public var initialEvent: Event?
}

extension VoipNotification: PKPushRegistryDelegate {
    
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else {
            return
        }
        print("VOIP TOKEN ADDED: \((pushCredentials.token as NSData).description)")
        deviceToken = pushCredentials.token
        initialEvent = Event.register(pushCredentials.token)
        if let initialEvent = initialEvent {
            notifyObservers(initialEvent)
        } else {
            print("initialEvent is nil")
        }
       
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP,
            let deviceToken = deviceToken else {
                return
        }
        
        print("VOIP TOKEN REMOVED: \(deviceToken)")
        initialEvent = Event.unregister(deviceToken)
        notifyObservers(initialEvent!)
    }
    
   
    
    public func pushRegistry(_ registry: PKPushRegistry,
                             didReceiveIncomingPushWith payload: PKPushPayload,
                             for type: PKPushType,
                             completion: @escaping () -> Void
    ) {
        print("VOIP PUSH RECIEVED")
                
        guard type == .voIP else { return }

        if CallMagic.provider == nil {
            CallMagic.provider = CallProvider()
        }
        
        if CallMagic.UID != nil {
            CallMagic.UID = UUID()
        }
        
        if payload.dictionaryPayload["twi_message_type"] as? String == "twilio.voice.call" {
        
            if let handler = notificationHandler {
                handler.handleVoipNotification(payload.dictionaryPayload)
            } else {
                pendingNotification = payload.dictionaryPayload
            }
            
            let set = CharacterSet(charactersIn: "+1234567890")
            let twi_from = ((payload.dictionaryPayload["twi_from"] as? String) ?? "Connecting..")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .trimmingCharacters(in: set.inverted)
            
            CallMagic.update = CXCallUpdate()
            CallMagic.update?.remoteHandle = CXHandle(type: .generic, value: twi_from)
            CallMagic.update?.supportsDTMF = true
            CallMagic.update?.supportsHolding = false
            CallMagic.update?.supportsGrouping = false
            CallMagic.update?.supportsUngrouping = false
            CallMagic.update?.hasVideo = false
            CallMagic.update?.localizedCallerName = twi_from
               
            if let uid = CallMagic.UID , let provider = CallMagic.provider, let update = CallMagic.update {
                CallMagic.update = nil
                provider.reportIncomingCall(from: uid , with: update) { _ in
                    print("Incoming first reportIncomingCall ok")
                    completion()
                }
            }
            
        } else if payload.dictionaryPayload["twi_message_type"] as? String == "twilio.voice.cancel"
                    ||
                    payload.dictionaryPayload["twi_message_type"] as? String == "twilio.voice.end" {
            
            if let uid = CallMagic.UID , let provider = CallMagic.provider {
                
                if let handler = notificationHandler {
                    handler.handleVoipNotification(payload.dictionaryPayload)
                } else {
                    pendingNotification = payload.dictionaryPayload
                }
                
                print("Incoming close ok")
                provider.close(from: uid)
            }
        }
    }
}
