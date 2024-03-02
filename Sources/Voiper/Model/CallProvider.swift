

import Foundation
import AVFoundation
import PushKit
import CallKit
import TwilioVoice
import UIKit

protocol CallProviderDelegate: AnyObject {
    func providerReportStartCall(with uuid: UUID, with completion: @escaping (Bool) -> ())
    func providerReportAnswerCall(with uuid: UUID, with completion: @escaping (Bool) -> ())
    func providerReportEndCall(with uuid: UUID)
    func providerReportHoldCall(with uuid: UUID, _ onHold: Bool) -> Bool
    func providerReportMuteCall(with uuid: UUID, _ onMute: Bool) -> Bool
    func providerReportSendDTMF(with uuid: UUID, _ digits: String) -> Bool
    
    func providerRepordAudioSessionActivation()
    func providerRepordAudioSessionDeactivation()
}

public final class CallProvider: NSObject {
    private let provider: CXProvider
    weak var delegate: CallProviderDelegate?
    
    var audioDevice = DefaultAudioDevice()

    public override init() {
        
        var name: String

        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let productName = dict["CFBundleName"] as? String {
            name = productName
        } else {
            name = "Voiper"
            
        }

        let configuration = CXProviderConfiguration(localizedName: name)
        
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.phoneNumber]
        provider = CXProvider(configuration: configuration)
        
        super.init()
        provider.setDelegate(self, queue: nil)
        TwilioVoiceSDK.audioDevice = audioDevice
    }
    
    func updateCall(with uuid: UUID, _ callUpdate: CXCallUpdate) {
        provider.reportCall(with: uuid, updated: callUpdate)
    }
    
    func reportIncomingCall(from uuid: UUID, with update: CXCallUpdate, _ completion: @escaping (Error?) -> ()) {
        provider.reportNewIncomingCall(with: uuid, update: update, completion: completion)
    }
    
    func reportOutgoingCall(with uuid: UUID, connectedAt dateConnected: Date?) {
        provider.reportOutgoingCall(with: uuid, connectedAt: dateConnected)
    }
    
    func close(from uuid: UUID, reason: CXCallEndedReason = .failed) {
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
    }
    
    func invilidate() {
        provider.invalidate()
    }
}

// MARK: - CXProviderDelegate
extension CallProvider: CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        audioDevice.isEnabled = true
    }
    
    public func providerDidBegin(_ provider: CXProvider) { }
    
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = true
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = false
    }
    
    public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) { }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        guard let delegate = delegate else {
            action.fail()
            return
        }
        
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        delegate.providerReportStartCall(with: action.callUUID) { success in
            if success {
//                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        guard let delegate = delegate else {
            action.fail()
            return
        }
        delegate.providerReportAnswerCall(with: action.callUUID) { success in
            if (success) {
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let delegate = delegate else {
            action.fail()
            return
        }
        delegate.providerReportEndCall(with: action.callUUID)
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        if let delegate = delegate,
            delegate.providerReportHoldCall(with: action.callUUID, action.isOnHold) {
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if let delegate = delegate,
            delegate.providerReportMuteCall(with: action.callUUID, action.isMuted) {
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    public func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        if let delegate = delegate,
            delegate.providerReportSendDTMF(with: action.callUUID, action.digits) {
            action.fulfill()
        } else {
            action.fail()
        }
    }
}
