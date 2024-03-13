import Foundation
import FirebaseCrashlytics
import PromiseKit
import AVFoundation
import TwilioVoice
import TelnyxRTC

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
    private let service: Service
    private let accountManager: AccountManager?
    
    init(phoneModel: PhoneModel, service: Service, accountManager: AccountManager? = nil) {
        self.service = service
        self.phoneModel = phoneModel
        self.phoneNumber = phoneModel.phoneNumber
        self.accountManager = accountManager

        super.init()
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
            do {
                let telnyxClient = TxClient()
                try telnyxClient
                    .connect(
                        txConfig: TxConfig(
                            sipUser: accessData.username, 
                            password: accessData.password,
                            pushDeviceToken: deviceToken.reduce("", {$0 + String(format: "%02X", $1) })
                        ),
                        serverConfiguration: TxServerConfiguration(
                            environment: .production,
                            pushMetaData: [
                                "telnyxNumber": phoneNumber.number,
                                "numberID": phoneNumber.id
                            ]
                        )
                    )
                telnyxClient.disconnect()
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
                let telnyxClient = TxClient()
                try telnyxClient
                    .connect(
                        txConfig: TxConfig(
                            sipUser: telnyx.username,
                            password: telnyx.password
                        ),
                        serverConfiguration: TxServerConfiguration(environment: .production)
                    )
                DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [telnyxClient] in
                    telnyxClient.disconnect()
                }
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
                    .start(SPCall(uuid: UUID(), handle: number, isOutgoing: true, callerNumber: phoneNumber.number, numberProvider: phoneNumber.provider))
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
