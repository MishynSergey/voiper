import Foundation
import FirebaseCrashlytics
import PromiseKit
import AVFoundation
import TwilioVoice
import TelnyxRTC

public class CallManager: NSObject {
    
    static var txServerConfig: TxServerConfiguration = {
        #if DEBUG
        return TxServerConfiguration(environment: .development)
        #else
        return TxServerConfiguration(environment: .production)
        #endif
    }()
    
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
    
    init(phoneModel: PhoneModel, service: Service, accountManager: AccountManager? = nil) {
        self.service = service
        self.phoneModel = phoneModel
        self.phoneNumber = phoneModel.phoneNumber
        self.accountManager = accountManager
        
        self.telnyxClient = phoneModel.phoneNumber.provider == .telnyx ? TxClient() : nil
        
        super.init()
    }

    static func getAccess() -> Guarantee<Bool> {
        return Guarantee { seal in
            AVAudioSession.sharedInstance().requestRecordPermission { success in
                seal(success)
            }
        }
    }
    
    func fetchAccessToken() -> Promise<String> {
        let promise: Promise<TwilioAccessTokenResponse> = service.execute(.getCallAccessToken(phoneNumber.id))
        return promise.map { response -> String in
            return response.token
        }
    }
    
    private func registerForPush(with deviceToken: Data) {
        guard phoneNumber.isActive else { return }
        _ = fetchAccessToken()
            .then { [weak self] token -> Promise<Void> in
                guard let self else { return Promise() }
                switch phoneNumber.provider {
                case .twilio:
                    return registerForPushFromTwilio(with: deviceToken, and: token)
                case .telnyx:
                    return registerForPushFromTelnyx(with: deviceToken, and: token)
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

    private func registerForPushFromTelnyx(with deviceToken: Data, and accessToken: String) -> Promise<Void> {
        return Promise { [weak self] seal in
            guard let self else { seal.reject(ServiceError.undefined); return }
            do {
                try telnyxClient?
                    .connect(
                        txConfig: TxConfig(
                            token: accessToken,
                            pushDeviceToken: deviceToken.reduce("", {$0 + String(format: "%02X", $1) })
                        ),
                        serverConfiguration: CallManager.txServerConfig
                    )
                seal.fulfill(())
            } catch {
                Crashlytics.crashlytics().record(error: error)
                seal.reject(error)
            }
        }
    }
    
    private func unregisterForPush(with deviceToken: Data) {
        switch phoneNumber.provider {
        case .twilio:
            unregisterForPushFromTwilio(with: deviceToken)
        case .telnyx:
            unregisterForPushFromTelnyx()
        case .unknown:
            return
        }
    }
    
    private func unregisterForPushFromTwilio(with deviceToken: Data) {
        _ = fetchAccessToken()
            .then { token -> Promise<Void> in
                return Promise { seal in
                    TwilioVoiceSDK.unregister(accessToken: token, deviceToken: deviceToken, completion: { error in
                        if let error = error {
                            seal.reject(error)
                        } else {
                            seal.fulfill(())
                        }
                    })
                }
            }
    }
    
    private func unregisterForPushFromTelnyx() {
        guard let telnyxClient else { return }
        telnyxClient.disablePushNotifications()
    }
    
    
    public func call(for number: String, completion: @escaping (Swift.Result<Void, Error>) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            accountManager?.updateCallFlow()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                AccountManager
                    .callFlow
                    .start(SPCall(uuid: UUID(), handle: number, isOutgoing: true, telnyxClient: self.telnyxClient, callerNumber: phoneNumber.formattedNumber))
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
}
