import Foundation
import UIKit
import TwilioVoice
import PromiseKit
import CallKit

public protocol CallIntentHandler {
    func handleStartCallIntent(_ handle: String)
}

public protocol VoipNotificationHandler: AnyObject {
    func handleTwilioVoipNotification(_ payload: [AnyHashable: Any])
}

public class CallFlow: NSObject, OnNotification {
    public var handler = NotificationHandler()
    
    static let windowLevel = UIWindow.Level.alert + 2
    private var callModel: CallModel?
    weak var callManager: CallManager?
    private var callViewController: CallVCDatasource?
    private var endCallViewController: EndCallVCDatasource?
    
    private let provider: CallProvider = {
        if let provider = CallMagic.provider {
            return provider
        } else {
            CallMagic.provider = CallProvider()
            return CallMagic.provider!
        }
    }()
    
    private let window: UIWindow = {
        let rect = UIScreen.main.bounds
        let window = UIWindow(frame: rect)
        window.windowLevel = CallFlow.windowLevel
        return window
    }()
    
    override init() {
        super.init()
        
        handler.registerNotificationName(UIApplication.willEnterForegroundNotification) { [unowned self] _ in
            if self.callModel != nil {
                self.showCall()
            }
        }
        
        handler.registerNotificationName(Notification.Name(rawValue: "ShowCall")) { [unowned self] _ in
            if self.callModel != nil {
                self.showCall()
            }
        }
    }
    
    public func start(_ call: SPCall) -> Promise<Void> {
        return Promise { [weak self] seal in
            guard let self else { seal.fulfill(()); return }
          
            guard callModel == nil, let callManager, callManager.phoneNumber.isActive else {
                seal.reject(ServiceError.innactiveNumber)
                return
            }
            
            guard call.handle.count > 5 else {
                    seal.resolve(nil)
                    return
            }
             
            self.callModel = CallModel(call: call, callFlow: self, callProvider: provider, callManager: callManager)
            
            self.provider.delegate = self.callModel
            
            if call.isOutgoing == true {
                self.showCall()
            }
            
            seal.fulfill(())
        }
    }
    
    public func endCall() {
        guard let endCallViewController = endCallViewController,
              let callModel = callModel else { hideCall(); return }

        endCallViewController.callWasEnded(callModel: callModel)
        window.rootViewController = endCallViewController
    }

    func hideCall() {
        UIView.animate(withDuration: 0.25, animations: {
            self.window.alpha = 0
        }, completion: { _ in
            self.window.isHidden = true
            self.window.rootViewController = nil
            self.window.alpha = 1
            self.callModel = nil
            self.callManager?.phoneModel.activityModel.update()
        })
    }
    
    func showCall() {
        guard let callModel = callModel else { return }
        DispatchQueue.main.async {
            if callModel.callVC == nil {
                let controller = self.callViewController
                self.endCallViewController?.callWasStarted()
                controller?.configure(callModel: callModel)
                self.window.rootViewController = controller
                self.window.makeKeyAndVisible()
                callModel.callVC = controller
            }
            
            self.window.isHidden = false
            self.window.alpha = 1
        }
    }
    
    
    public func setCallVC(vc: CallVCDatasource) {
        self.callViewController = vc
    }

    public func setEndCallVC(vc: EndCallVCDatasource) {
        self.endCallViewController = vc
        endCallViewController?.endAction = { [weak self] in
            guard let self = self else { return }
            self.hideCall()
        }
    }
    
    private func hideWindow() {
        window.isHidden = true
        window.rootViewController = nil
    }
}

extension CallFlow: VoipNotificationHandler {
    public func handleTwilioVoipNotification(_ payload: [AnyHashable: Any]) {
        print("TWILIO HANDLE VOIP")
        TwilioVoiceSDK.handleNotification(payload, delegate: self, delegateQueue: nil)
    }
}

extension CallFlow: CallIntentHandler {
    
    public func handleStartCallIntent(_ handle: String) {
        let set = CharacterSet(charactersIn: "+1234567890")
        let cleanHandle = handle.replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
        .trimmingCharacters(in: set.inverted)
        
        if let uid = CallMagic.UID {
            let call = SPCall(uuid: uid, handle: cleanHandle, isOutgoing: true)
            _ = start(call)
        } else {
            print("TWILIO INVITE NO UID")
        }
    
    }
}

extension CallFlow: NotificationDelegate {
    public func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        callModel?.handleNotifiactionCancel(cancelledCallInvite)
    }
    
    public func callInviteReceived(callInvite: CallInvite) {
        if let uid = CallMagic.UID {
            let call = SPCall(uuid: uid , handle: callInvite.from ?? "")
            call.twilioCallInvite = callInvite
            _ = start(call)
        }
    }
    
    func notificationError(_ error: Error) {
        print("Twilio notification error: \(error.localizedDescription)")
    }
}

