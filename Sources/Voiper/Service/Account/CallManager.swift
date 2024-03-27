import Foundation
import KeychainAccess
import FirebaseCrashlytics
import PromiseKit
import AVFoundation
import TwilioVoice
import TelnyxRTC
import Combine

public class CallManager: NSObject {

    private var observerToken = 0
    weak var voipNotification: VoipNotification? {
        didSet {
            if let oldValue {
                oldValue.removeObserver(observerToken)
            }
            if let model = voipNotification {
                observerToken = model.observe { [weak self] event in
                    guard let self else { return }
                    switch event {
                    case .register(let token):
                        registerForPush(with: token)
                    case .unregister(let token):
                        unregisterForPush(with: token)
                    }
                }
            }
        }
    }
    
    unowned var phoneModel: PhoneModel
    let phoneNumber: PhoneNumber
    private (set) var telnyxClient: TxClient?
    private let service: Service
    private let accountManager: AccountManager?
    private let telnyxCallStateUpdates = CurrentValueSubject<(UUID, TelnyxRTC.CallState)?, Never>(nil)
    
    init(phoneModel: PhoneModel, service: Service, accountManager: AccountManager? = nil) {
        self.service = service
        self.phoneModel = phoneModel
        self.phoneNumber = phoneModel.phoneNumber
        self.accountManager = accountManager
        self.telnyxClient = phoneModel.phoneNumber.provider == .telnyx ? TxClient() : nil
        super.init()
        telnyxClient?.delegate = self
    }

    static func getAccess() -> Guarantee<Bool> {
        return Guarantee { seal in
            AVAudioSession.sharedInstance().requestRecordPermission { success in
                seal(success)
            }
        }
    }
    
    func fetchAccessToken() -> Promise<AccessData> {
        let promise: Promise<AccessData> = service.execute(.getCallAccessToken(phoneNumber.id))
        return promise
    }
    
    private func registerForPush(with deviceToken: Data) {
        guard phoneNumber.isActive else { return }
        _ = fetchAccessToken()
            .then { [weak self] token -> Promise<Void> in
                guard let self else { return Promise() }
                switch phoneNumber.provider {
                case .twilio:
                    return registerForPushFromTwilio(with: deviceToken, and: token.token)
                case .telnyx:
                    return registerForPushFromTelnyx(with: deviceToken, and: token.data!)
                case .unknown:
                    return Promise()
                }
            }
    }
    
    private func registerForPushFromTwilio(with deviceToken: Data, and accessToken: String) -> Promise<Void> {
        return Promise { seal in
            TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: deviceToken, completion: { error in
                if let error = error {
                    seal.reject(error)
                } else {
                    print("Registred for ring with \(accessToken) for device \(deviceToken)")
                    seal.fulfill(())
                }
            })
        }
    }

    private func registerForPushFromTelnyx(with deviceToken: Data, and accessData: TelnyxCredentials) -> Promise<Void> {
        return Promise { [weak self] seal in
            guard let self else { seal.reject(ServiceError.undefined); return }
            Settings.sipUsername = accessData.username
            Settings.sipPassword = accessData.password
            do {
                try telnyxClient?
                    .connect(
                        txConfig: TxConfig(
                            sipUser: accessData.username, 
                            password: accessData.password,
                            pushDeviceToken: deviceToken.reduce("", {$0 + String(format: "%02X", $1) })
                        ),
                        serverConfiguration: TxServerConfiguration(
                            environment: .production,
                            pushMetaData: [
                                "telnyxNumber": "\(phoneNumber.number)",
                                "numberID": "\(phoneNumber.id)"
                            ]
                        )
                    )
                telnyxClient?.delegate = self
                seal.fulfill(())
            } catch {
                Crashlytics.crashlytics().record(error: error)
                seal.reject(error)
            }
        }
    }
    
    private func unregisterForPush(with deviceToken: Data) {
        _ = fetchAccessToken()
            .then { [weak self] accessData -> Promise<Void> in
                guard let self else { return Promise() }
                switch phoneNumber.provider {
                case .twilio:
                    return unregisterForPushFromTwilio(with: deviceToken, and: accessData)
                case .telnyx:
                    return unregisterForPushFromTelnyx(with: accessData)
                case .unknown:
                    return Promise()
                }     
            }
    }
    
    private func unregisterForPushFromTwilio(with deviceToken: Data, and accessData: AccessData) -> Promise<Void> {
        Promise { seal in
            TwilioVoiceSDK.unregister(accessToken: accessData.token, deviceToken: deviceToken, completion: { error in
                if let error = error {
                    seal.reject(error)
                } else {
                    seal.fulfill(())
                }
            })
        }
    }
    
    private func unregisterForPushFromTelnyx(with accessData: AccessData) -> Promise<Void> {
        return Promise { seal in
            guard let telnyx = accessData.data else { seal.reject(ServiceError.undefined); return }
            do {
                try telnyxClient?
                    .connect(
                        txConfig: TxConfig(
                            sipUser: telnyx.username,
                            password: telnyx.password
                        ),
                        serverConfiguration: TxServerConfiguration(environment: .production)
                    )
                seal.fulfill(())
            } catch {
                Crashlytics.crashlytics().record(error: error)
                seal.reject(error)
            }
        }
    }
    
    
    public func call(for number: String, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            accountManager?.updateCallFlow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                AccountManager
                    .callFlow
                    .start(SPCall(uuid: UUID(), handle: number, isOutgoing: true, numberProvider: phoneNumber.provider))
                    .done { _ in completion(.success(())) }
                    .catch { error in completion(.failure(error)) }
            }
        case .denied, .restricted:
            completion(.failure(ServiceError.noAccessToMicrophone))
        case .notDetermined:
            requestAccessToMicrophone() { [weak self, completion, number] granted in
                guard let self else { return }
                if granted {
                    call(for: number, completion: completion)
                } else {
                    completion(.failure(ServiceError.noAccessToMicrophone))
                }
            }
        @unknown default:
            completion(.failure(ServiceError.noAccessToMicrophone))
        }
        
    }
    
    private func requestAccessToMicrophone(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { [completion] (granted) in completion(granted) }
    }
    
    func processTwilioVoIPCall(payload: [AnyHashable: Any]) {
        print("TWILIO HANDLE VOIP")
        TwilioVoiceSDK.handleNotification(payload, delegate: self, delegateQueue: nil)
    }
    
    func processTelnyxVoIPCall(_ callUUID: UUID, metadata: [String: Any]) -> Promise<Void> {
        VLogger.info("called \(#function)")
//        return fetchAccessToken()
//            .then { [weak self] accessData in
//                guard let self, let telnyxData = accessData.data else { return Promise<Void>(error: ServiceError.undefined) }
        guard let username = Settings.sipUsername, let password = Settings.sipPassword else { return Promise<Void>(error: ServiceError.undefined) }
                do {
                    telnyxClient = TxClient()
                    telnyxClient?.delegate = self
                    try telnyxClient?
                        .processVoIPNotification(
                            txConfig: TxConfig(
                                sipUser: username,
                                password: password,
                                pushDeviceToken: Settings.devicePushToken?
                                    .reduce("", {$0 + String(format: "%02X", $1) }),
                                logLevel: .all,
                                reconnectClient: false
                            ),
                            serverConfiguration: TxServerConfiguration(
                                environment: .production
                            ),
                            pushMetaData: metadata
                        )
                } catch {
                    VLogger.error("in \(#function) during processVoIPNotification(...) cathced error: \(error)")
                    Crashlytics.crashlytics().record(error: error)
                    Promise<Void>(error: error)
                }
                return Promise.value(Void())
//            }
    }
    
    func connectRemoteCallWithLocalCall(_ call: SPCall) -> Promise<Void> {
        fetchAccessToken()
            .then { [weak self, call] token in
                guard let self = self else { return Promise<Void>(error: ServiceError.undefined) }
                switch phoneNumber.provider {
                case .twilio:
                    call.twilioCall = createTwilioRemoteWithToken(token.token, handle: call.handle, delegate: call)
                case .telnyx:
                    guard let telnyxData = token.data else { return Promise<Void>(error: ServiceError.undefined) }
                    do {
                        call.telnyxCallStatePublisher = telnyxCallStateUpdates.compactMap { $0 }.eraseToAnyPublisher()
                        try call.txCall = createTelnyxRemoteWithToken(telnyxData, callUUID: call.uuid, handle: call.handle)
                    } catch {
                        telnyxCallStateUpdates.send((call.uuid, .DONE))
                        Promise<Void>(error: error)
                    }
                case .unknown:
                    Promise<Void>(error: ServiceError.undefined)
                }
                return Promise.value(Void())
                
            }
    }
    
    private func createTwilioRemoteWithToken(_ token: String, handle: String, delegate: TwilioVoice.CallDelegate) -> TwilioVoice.Call {
        let option = ConnectOptions(accessToken: token) { [handle] builder in
            builder.params = ["To": handle]
        }
        return TwilioVoiceSDK.connect(options: option, delegate: delegate)
    }
    
    private func createTelnyxRemoteWithToken(_ accessData: TelnyxCredentials, callUUID: UUID, handle: String) throws -> TelnyxRTC.Call {
        guard let telnyxClient else { throw ServiceError.undefined }
        if !telnyxClient.isConnected() {
            try telnyxClient
                .connect(
                    txConfig: TxConfig(
                        sipUser: accessData.username,
                        password: accessData.password,
                        pushDeviceToken: Settings.devicePushToken?
                            .reduce("", {$0 + String(format: "%02X", $1) })
                    ),
                    serverConfiguration: TxServerConfiguration(environment: .production)
                )
        }
        return try telnyxClient
            .newCall(
                callerName: phoneNumber.number,
                callerNumber: phoneNumber.number,
                destinationNumber: handle,
                callId: callUUID
            )
    }
}

extension CallManager: NotificationDelegate {
    public func callInviteReceived(callInvite: CallInvite) {
        let call = SPCall(uuid: callInvite.uuid, handle: callInvite.from ?? "", numberProvider: .twilio)
        call.twilioCallInvite = callInvite
        AccountManager
            .callFlow
            .start(call)
    }
    
    public func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        AccountManager
            .callFlow
            .handleCancelledCallInvite(cancelledCallInvite)
        Crashlytics.crashlytics().record(error: error)
    }
}

extension CallManager: TxClientDelegate {
    public func onSocketConnected() {
        
    }
    
    public func onSocketDisconnected() {
        
    }
    
    public func onClientError(error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
    
    public func onClientReady() {
        
    }
    
    public func onPushDisabled(success: Bool, message: String) {
        
    }
    
    public func onSessionUpdated(sessionId: String) {
        
    }
    
    public func onCallStateUpdated(callState: TelnyxRTC.CallState, callId: UUID) {
        telnyxCallStateUpdates.send((callId, callState))
    }
    
    public func onIncomingCall(call: TelnyxRTC.Call) {
        
    }
    
    public func onRemoteCallEnded(callId: UUID) {
//        CallMagic.provider?.close(from: callId, reason: .remoteEnded)
    }
    
    public func onPushCall(call: TelnyxRTC.Call) {
        VLogger.info("called \(#function)")
        let spCall = SPCall(
            uuid: call.callInfo?.callId ?? CallMagic.UID ?? UUID(),
            handle: call.callInfo?.callerNumber ?? call.callInfo?.callerName ?? "",
            isOutgoing: false,
            numberProvider: .telnyx
        )
        AccountManager
            .callFlow
            .start(spCall)
    }
}

