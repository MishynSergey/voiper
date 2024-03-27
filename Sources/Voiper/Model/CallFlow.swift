import Foundation
import UIKit
import TwilioVoice
import PromiseKit
import CallKit

protocol VoipNotificationHandler: AnyObject {
    func handleTwilioVoipNotification(_ payload: [AnyHashable: Any]) throws
    func handleTelnyxVoipNotification(_ payload: [AnyHashable: Any]) -> Promise<Void>
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
        VLogger.info("VOIP PUSH RECIEVED")
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
    
    func handleCancelledCallInvite(_ callInvite: CancelledCallInvite) {
        callModel?.handleNotifiactionCancel(callInvite)
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
    func handleTwilioVoipNotification(_ payload: [AnyHashable: Any]) throws {
        VLogger.info("called \(#function)")
        guard let twilioPhoneModel = AccountManager.shared.phoneManager.phoneModels.first(where: { $0.phoneNumber.isActive && $0.phoneNumber.provider == .twilio }) else {
            throw ServiceError.undefined
        }
        callManager = twilioPhoneModel.callManager
        twilioPhoneModel.callManager.processTwilioVoIPCall(payload: payload)
    }
    
    func handleTelnyxVoipNotification(_ payload: [AnyHashable: Any]) -> Promise<Void> {
        VLogger.info("called \(#function)")
        guard let telnyxPhoneModel = AccountManager.shared.phoneManager.phoneModels.first(where: { $0.phoneNumber.isActive && $0.phoneNumber.provider == .telnyx }) else {
            VLogger.error("in \(#function) didnt find telnyxPhoneModel")
            return Promise<Void>(error: ServiceError.undefined)
        }
        callManager = telnyxPhoneModel.callManager
        guard let metadata = payload["metadata"] as? [String: Any] else {
            VLogger.error("in \(#function) didnt find metadata")
            return Promise<Void>(error: ServiceError.undefined)
        }
        let callUUID: UUID
        if let callIDString = metadata["call_id"] as? String, !callIDString.isEmpty, let uuid = UUID(uuidString: callIDString) {
            callUUID = uuid
        } else {
            callUUID = UUID()
        }
        return telnyxPhoneModel.callManager.processTelnyxVoIPCall(callUUID, metadata: metadata)
    }
}

