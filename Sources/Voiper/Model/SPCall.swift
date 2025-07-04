import Foundation
import TwilioVoice
import PromiseKit
import CallKit


public class SPCall: NSObject {
    private var webSocket : URLSessionWebSocketTask?

    public let uuid: UUID
    public let isOutgoing: Bool
    public var handle: String
    
    private var _state: State = .none {
        didSet {
            onUpdateState?()
        }
    }
    public var state: State {
        get {
            return _state
        }
        set {
            if newValue > _state {
                _state = newValue
            }
        }
    }
    
    public var twilioCallInvite: CallInvite?
    public var twilioCall: Call?
    
    public var connectingDate: Date?
    public var connectDate: Date?
    public var endDate: Date?
    
    var isOnHold: Bool {
        set {
            twilioCall?.isOnHold = newValue
        }
        get {
            return twilioCall?.isOnHold ?? false
        }
    }
    public var isMuted: Bool {
        set {
            twilioCall?.isMuted = newValue
        }
        get {
            return twilioCall?.isMuted ?? false
        }
    }
    
    var userID: Int = 0
    var callConnectBlock: (() -> ())?
    var callDisconnectBlock: ((Error?) -> ())?
    var onUpdateState: (() -> Void)?
    
    public var duration: TimeInterval {
        guard let connectDate = connectDate else {
            return 0
        }
        
        return Date().timeIntervalSince(connectDate)
    }
    
    private var socketURL: String {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let baseURL = dict["socketBaseURL"] as? String {
            return baseURL
        } else {
            fatalError("add socketBaseURL -> Info.plist")
        }
    }
    
    public init(uuid: UUID, handle: String, isOutgoing: Bool = false) {
        self.uuid = uuid
        self.isOutgoing = isOutgoing
        self.handle = handle
    }
    
    deinit {
        closeSession()
    }
    
    func connect(with token: String) {
        state = .start
        connectingDate = Date()
       
        let option = ConnectOptions(accessToken: token) { [handle] builder in
            builder.params = ["To": handle]
        }
       
        twilioCall = TwilioVoiceSDK.connect(options: option, delegate: self)
        createSocket()
    }
    
    func answer() -> Bool {
        guard let invite = twilioCallInvite else {
            return false
        }
        connectingDate = Date()
        state = .start
        
        //migrate
        
        self.twilioCall = invite.accept(with: self)
       
        twilioCallInvite = nil
        createSocket()
        return true
    }
    
    public func sendDigits(_ digits: String) {
        twilioCall?.sendDigits(digits)
    }
    
    func disconnect() {
        //migrate
        if let invite = twilioCallInvite {
            invite.reject()
            twilioCallInvite = nil
            state = .ended
            endDate = Date()
        } else if let twCall = twilioCall {
            twCall.disconnect()
            twilioCall = nil
            state = .ending
        }
    }

    private func createSocket() {
        guard webSocket == nil else { return }
        //Session
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        
        //Server API
        let url = URL(string: "\(socketURL)/socket/websocket?token=\(Settings.userToken ?? "")")
        
        //Socket
        webSocket = session.webSocketTask(with: url!)
        
        //Connect and hanles handshake
        webSocket?.resume()
    }
}

extension SPCall: CallDelegate {
    public func callDidDisconnect(call: Call, error: Error?) {
        if let error = error {
            state = .failed(error)
            print("Call failed: \(error.localizedDescription)")
        } else {
            state = .ended
            endDate = Date()
            print("Call disconnected")
        }
        
        callDisconnectBlock?(error)
        closeSession()
    }
    
    
    public func callDidFailToConnect(call: Call, error: Error) {
        print("Call failed to connect: \(error.localizedDescription)")
        state = .failed(error)
        callDisconnectBlock?(error)
        closeSession()
    }
  
    public func callDidConnect(call twilioCall: Call) {
        print("callDidConnect:")
        if isOutgoing {
            state = .connecting
        } else {
            state = .connected
            connectDate = Date()
        }
        callConnectBlock?()
    }
}

extension SPCall: URLSessionWebSocketDelegate {
    private func receive(){
        DispatchQueue.global().async {
            self.webSocket?.receive() { [weak self] result in
                guard let self,
                    case let .success(message) = result,
                    case let .string(jsonString) = message,
                    let jsonData = jsonString.data(using: .utf8) else { return }
                
                do {
                    let phxData = try JSONDecoder().decode(PHXData.self, from: jsonData)
                    if phxData.payload.parentCallSid == twilioCall?.sid, phxData.payload.status == "in-progress" {
                        state = .connected
                        connectDate = Date()
                        closeSession()
                    }
                } catch {
                    print(error)
                }
                
                receive()
            }
            
        }
    }

    private func send(_ data: PHXData) {
        DispatchQueue.global().async {
            do {
                self.webSocket?.send(.data(try JSONEncoder().encode(data))) { [weak self] error in
                    guard let self, error == nil else { return }
                    receive()
                }
            } catch {
                print("Error encoding object to JSON: \(error)")
            }
        }
    }
    
    private func closeSession() {
        guard webSocket?.state == .running || webSocket?.state == .completed else { return }
        webSocket?.cancel(with: .goingAway, reason: "You've Closed The Connection".data(using: .utf8))
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        send(PHXData(event: "phx_join", topic: "dial:\(userID)", payload: PHXData.Payload()))
    }
    
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {

    }
}

public extension SPCall {
    enum State: Equatable, Comparable {
        case none
        case pending
        case start
        case connecting
        case connected
        case ending
        case ended
        case failed(Error?)

        public static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs ) {
            case (.none, .none):
                return true
            case (.pending, .pending):
                return true
            case (.start, .start):
                return true
            case (.connecting, .connecting):
                return true
            case (.connected, .connected):
                return true
            case (.ending, .ending):
                return true
            case (.ended, .ended):
                return true
            case (.failed(_), .failed(_)):
                return true
            default:
                return false
            }
        }
        
        public static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs == .failed(nil), rhs == .ended || rhs == .ending { return true }
            if rhs == .failed(nil) { return true }
            return lhs.index < rhs.index
        }
        
        private var index: Int {
            switch self {
            case .none:
                return 0
            case .pending:
                return 1
            case .start:
                return 2
            case .connecting:
                return 3
            case .connected:
                return 4
            case .ending:
                return 5
            case .ended:
                return 6
            case .failed:
                return 7
            }
        }
    }
}
