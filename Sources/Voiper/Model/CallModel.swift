import Foundation
import TwilioVoice
import PromiseKit
import CallKit
import TelnyxRTC

public class CallModel {
    
    var audioDevice = DefaultAudioDevice()
    
    init(call: SPCall, callFlow: CallFlow, callProvider: CallProvider, callManager: CallManager!) {
        self.call = call
        self.callFlow = callFlow
        self.callProvider = callProvider
        self.callManager = callManager
        
        self.call.userID = AccountManager.shared.account?.id ?? 0

        observeCall()
        handleCall()
    }

    unowned let callFlow: CallFlow
    private unowned let callManager: CallManager
    private unowned let callProvider: CallProvider
    
    public let call: SPCall
    var callVC: CallVCDatasource? {
        didSet {
            callVC?.updateUI()
        }
    }
    private let callKitCallController = CXCallController()
    private var callKitCompletionCallback: ((Bool)-> ())? = nil
    public var contact: Contact?
    
    private func observeCall() {
        call.callConnectBlock = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.callKitCompletionCallback?(true)
            strongSelf.callKitCompletionCallback = nil
            strongSelf.callVC?.updateUI()
        }
        call.callDisconnectBlock = { [weak self] error in
            guard let strongSelf = self else {
                return
            }
            strongSelf.requestEnd(strongSelf.call)
        }
        
        call.onUpdateState = { [callVC] in callVC?.updateUI() }
    }
    
    func handleCall(completion: (()->())? = nil) {
        if call.isOutgoing {
            reqeustStart(call)
        } else {
            reportIncoming(call)
        }
    }
    
    func handleNotifiactionCancel(_ callInvite: CancelledCallInvite) {
        guard let inveite = call.twilioCallInvite,
              inveite.callSid == callInvite.callSid else {
            return
        }
        
        call.state = .ending
        requestEnd(call)
    }
}
    
// MARK: - Call Kit Actions
extension CallModel {
    private func reqeustStart(_ call: SPCall) {
        call.state = .start
        callVC?.updateUI()
        
        let callHandle = CXHandle(type: .phoneNumber, value: call.handle)
        
        let startCallAction = CXStartCallAction(call: call.uuid, handle: callHandle)
        ContactsManager.shared.contactBy(phone: call.handle, completion: { contact in
            startCallAction.contactIdentifier = contact?.fullName
        })
        let transaction = CXTransaction(action: startCallAction)
        
        callKitCallController.request(transaction)  { error in
            
            if let error = error {
                self.call.state = .failed(error)
                self.callVC?.updateUI()
                print("StartCallAction transaction request failed: \(error.localizedDescription)")
                print("call UUID \(call.uuid)")
                return
            }
            
            print("StartCallAction transaction request successful")
            print("call UUID \(call.uuid)")
            
            let callUpdate = CXCallUpdate()
            ContactsManager.shared.contactBy(phone: call.handle, completion: { contact in
                callUpdate.localizedCallerName = contact?.fullName
            })
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = false
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false
            
            
            self.callProvider.updateCall(with: call.uuid, callUpdate)
        }
    }
    
    private func reportIncoming(_ call: SPCall) {
        call.state = .pending
        callVC?.updateUI()
        
        let callHandle = CXHandle(type: .phoneNumber, value: call.handle)
        
        CallMagic.update?.remoteHandle = callHandle
        CallMagic.update?.supportsDTMF = true
        CallMagic.update?.supportsHolding = false
        CallMagic.update?.supportsGrouping = false
        CallMagic.update?.supportsUngrouping = false
        CallMagic.update?.hasVideo = false
       
        
        if let uid = CallMagic.UID , let provider = CallMagic.provider, let update = CallMagic.update {
            CallMagic.update = nil
            provider.reportIncomingCall(from: uid, with: update) { error in
              
                if let error = error {
                    self.call.state = .failed(error)
                    self.callVC?.updateUI()
                    print("Failed to report incoming call successfully: \(error.localizedDescription).")
                    print("call UUID \(call.uuid)")
                }
                
                print("Incoming call successfully reported.")
                print("call UUID \(call.uuid)")
            }
        }
    }
    
    public func requestEnd(_ call: SPCall) {
        if call.state == .connected, RemoteConfig.shared.shortCallRestriction,
           let duration = call.connectDate?.timeIntervalSinceNow,
           Int(abs(duration)) < RemoteConfig.shared.shortCallDuration {
            return
        }

        call.state = .ending
        callVC?.updateUI()

        let endCallAction = CXEndCallAction(call: call.uuid)
        let transaction = CXTransaction(action: endCallAction)
        callKitCallController.request(transaction) { error in
            if let error = error {
                print("EndCallAction transaction request failed: \(error.localizedDescription).")
                print("call UUID \(call.uuid)")
                return
            }
            print("EndCallAction transaction request successful")
            print("call UUID \(call.uuid)")
        }
    }
    
    public func requestAction(_ action: CXAction) {
        let transaction = CXTransaction(action: action)
        callKitCallController.request(transaction) { error in
            if let error = error {
                print("\(action.description): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CXProviderDelegate
extension CallModel: CallProviderDelegate {
    
     public func providerReportStartCall(with uuid: UUID, with completion: @escaping (Bool) -> ()) {
        guard call.uuid == uuid else {
            completion(false)
            return
        }
        audioDevice.isEnabled = false
        createTwilioCall(for: call, with: completion)
    }
    
    public func providerReportAnswerCall(with uuid: UUID, with completion: @escaping (Bool) -> ()) {
        guard call.uuid == uuid else {
            completion(false)
            return
        }
        audioDevice.isEnabled = false
        answer(call, with: completion)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "ShowCall"), object: nil)
    }
    
    public func providerReportEndCall(with uuid: UUID) {
        guard call.uuid == uuid else {
            return
        }
        
        if case SPCall.State.none = call.state {
        } else {
            call.disconnect()
        }
        callKitCompletionCallback?(false)
        callKitCompletionCallback = nil
        callVC?.updateUI()
        callVC?.durationTimer?.invalidate()
        call.endDate = Date()
        Double(1).delay {
            self.callFlow.endCall()
        }
    }
    
    public func providerReportHoldCall(with uuid: UUID, _ onHold: Bool) -> Bool {
        // TODO: Add Hold
        return false
    }
    
    public func providerReportMuteCall(with uuid: UUID, _ onMute: Bool) -> Bool {
        guard call.uuid == uuid else {
            return false
        }
        call.isMuted = onMute
        callVC?.updateUI()
        return true
    }
    
    public func providerReportSendDTMF(with uuid: UUID, _ digits: String) -> Bool {
        guard call.uuid == uuid else {
            return false
        }
        call.sendDigits(digits)
        callVC?.updateUI()
        return true
    }
}
    
// MARK: - Twilio Actions
extension CallModel {
    private func createTwilioCall(for call: SPCall, with completion: @escaping (Bool) -> ()) {
        _ = callManager.fetchAccessToken()
            .done { [weak self] token in
                guard let self = self else { return }
                call.connect(with: token)
                self.callVC?.updateUI()
                self.callKitCompletionCallback = completion
            }
            .catch { error in
                completion(false)
            }
    }

    private func answer(_ call: SPCall, with completion: @escaping (Bool) -> Swift.Void) {
        if call.answer() {
            callKitCompletionCallback = completion
        } else {
            completion(false)
        }
        callVC?.updateUI()
    }
}
