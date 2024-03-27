import Foundation
import FirebaseCrashlytics
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
    public var contact: Contact?
    
    private func observeCall() {
        call.callDisconnectBlock = { [weak self] error in
            guard let strongSelf = self else {
                return
            }
            strongSelf.requestEnd(strongSelf.call)
        }
        
        call.onUpdateState = { [weak self] state in
            guard let self else { return }
            callVC?.updateUI()

            guard call.isOutgoing else { return }
            switch (state, callManager.phoneNumber.provider) {
            case (.connecting, .twilio), (.connected, .telnyx):
                callProvider.reportOutgoingCall(with: call.uuid, connectedAt: Date())
            default:
                break
            }
        }
    }
    
    
    public var isMuted: Bool {
        switch callManager.phoneNumber.provider {
        case .twilio:
            return call.twilioCall?.isMuted ?? false
        case .telnyx:
            return !(callManager.telnyxClient?.isAudioDeviceEnabled ?? false)
        case .unknown:
            return false
        }
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
        
        let callHandle = CXHandle(type: callManager.phoneNumber.provider == .telnyx ? .generic : .phoneNumber, value: call.handle)
        let startCallAction = CXStartCallAction(call: call.uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)

        ContactsManager.shared.contactBy(phone: call.handle, completion: { contact in
            startCallAction.contactIdentifier = contact?.fullName
        })
        
        callKitCallController.request(transaction) { [weak self] error in
            guard let self else { return }

            if let error = error {
                call.state = .failed(error)
                callVC?.updateUI()
                Crashlytics.crashlytics().record(error: error)
                return
            }

            let callUpdate = CXCallUpdate()
            ContactsManager.shared.contactBy(phone: call.handle, completion: { contact in
                callUpdate.localizedCallerName = contact?.fullName
            })
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = callManager.phoneNumber.provider == .telnyx
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
            provider.reportIncomingCall(from: uid, with: update) { [weak self] error in
                guard let self else { return }
                if let error = error {
                    self.call.state = .failed(error)
                    self.callVC?.updateUI()
                    Crashlytics.crashlytics().record(error: error)
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
        callKitCallController.request(transaction) { [callFlow] error in
            if let error = error {
                Crashlytics.crashlytics().record(error: error)
                print("EndCallAction transaction request failed: \(error.localizedDescription).")
                print("call UUID \(call.uuid)")
                Double(1).delay { [callFlow] in
                    callFlow.endCall()
                }
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
                Crashlytics.crashlytics().record(error: error)
                print("\(action.description): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CXProviderDelegate
extension CallModel: CallProviderDelegate {
    
    func providerReportStartCall(with uuid: UUID, with completion: @escaping (Bool) -> ()) {
        guard call.uuid == uuid else {
            completion(false)
            return
        }
        audioDevice.isEnabled = false
        callManager.telnyxClient?.isAudioDeviceEnabled = false
        createCall(for: call, with: completion)
    }
    
    func providerReportAnswerCall(with action: CXAnswerCallAction, with completion: @escaping (Bool) -> ()) {
        VLogger.info("called \(#function)")
        guard call.uuid == action.callUUID else {
            VLogger.error("in \(#function) call.uuid and action.callUUID didn't match")
            completion(false)
            return
        }
        audioDevice.isEnabled = false
        callManager.telnyxClient?.isAudioDeviceEnabled = false
        answer(call, action: action, with: completion)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "ShowCall"), object: nil)
    }
    
    func providerReportEndCall(with action: CXEndCallAction) {
        guard call.uuid == action.callUUID else {
            return
        }
        
        callManager.telnyxClient?.endCallFromCallkit(endAction: action)
        if call.state != .none {
            call.disconnect(with: action)
        }
        callVC?.updateUI()
        callVC?.durationTimer?.invalidate()
        call.endDate = Date()
        Double(1).delay {
            self.callFlow.endCall()
        }
    }
    
    func providerReportHoldCall(with uuid: UUID, _ onHold: Bool) -> Bool {
        call.setOnHold(onHold)
        return true
    }
    
    func providerReportMuteCall(with uuid: UUID, _ onMute: Bool) -> Bool {
        guard call.uuid == uuid else {
            return false
        }
        call.setMuted(onMute)
        callVC?.updateUI()
        return true
    }
    
    func providerReportSendDTMF(with uuid: UUID, _ digits: String) -> Bool {
        guard call.uuid == uuid else {
            return false
        }
        call.sendDigits(digits)
        callVC?.updateUI()
        return true
    }
    
    func providerRepordAudioSessionActivation() {
        callManager.telnyxClient?.isAudioDeviceEnabled = true
    }
    
    func providerRepordAudioSessionDeactivation() {
        callManager.telnyxClient?.isAudioDeviceEnabled = false
    }
}
    
// MARK: - Twilio Actions
extension CallModel {
    private func createCall(for call: SPCall, with completion: @escaping (Bool) -> ()) {
        callManager
            .connectRemoteCallWithLocalCall(call)
            .done { [weak self] _ in
                guard let self else { return }
                self.callVC?.updateUI()
                completion(true)
            }
            .catch { error in
                Crashlytics.crashlytics().record(error: error)
                completion(false)
            }
    }

    private func answer(_ call: SPCall, action: CXAnswerCallAction, with completion: @escaping (Bool) -> Swift.Void) {
        VLogger.info("called \(#function)")
        switch callManager.phoneNumber.provider {
        case .twilio:
            completion(call.answer())
        case .telnyx:
            callManager.telnyxClient?.answerFromCallkit(answerAction: action)
        case .unknown:
            completion(false)
        }
        callVC?.updateUI()
    }
}
