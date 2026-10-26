import Foundation

public struct OnlineUserInfo: Identifiable, Equatable {
    public var id: String { userId }
    public let userId: String
    public let displayName: String
    public let platform: String

    public init(userId: String, displayName: String, platform: String) {
        self.userId = userId
        self.displayName = displayName
        self.platform = platform
    }
}

public enum SignalingEvent {
    case connected(userId: String)
    case disconnected(reason: String?)
    case onlineUsers(users: [OnlineUserInfo])
    case incomingCall(callId: String, callerId: String, callerPublicKey: String, audioCodec: String)
    case ringing(callId: String)
    case callAccepted(callId: String, calleePublicKey: String)
    case callRejected(callId: String, reason: String?)
    case relayInfo(callId: String, host: String, port: Int, sessionId: Int64, token: String)
    case binaryAudioReceived(data: Data)
    case callEnded(callId: String, reason: String)
    case error(message: String)
}

public protocol SignalingClientDelegate: AnyObject {
    func signalingClient(_ client: SignalingClient, didReceiveEvent event: SignalingEvent)
}

public final class SignalingClient: NSObject, URLSessionWebSocketDelegate {

    public weak var delegate: SignalingClientDelegate?
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var isConnected = false
    private var serverUrl: String = ""
    private var myUserId: String = ""
    private var myDisplayName: String = ""
    private var deviceId: String = ""
    private var reconnectTimer: Timer?

    public override init() {
        super.init()
    }

    public func connect(serverUrl: String, userId: String, deviceId: String, displayName: String = "") {
        self.serverUrl = serverUrl
        self.myUserId = userId
        self.myDisplayName = displayName
        self.deviceId = deviceId

        guard let url = URL(string: serverUrl) else { return }

        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()

        listenForMessages()
    }

    public func disconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        // 1. O'zini serverga ro'yxatga qo'yish
        let regDict: [String: Any] = [
            "type": "register",
            "userId": myUserId,
            "deviceId": deviceId,
            "platform": "ios",
            "displayName": myDisplayName
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: regDict),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            webSocketTask.send(.string(jsonStr)) { _ in }
        }
        DispatchQueue.main.async {
            self.delegate?.signalingClient(self, didReceiveEvent: .connected(userId: self.myUserId))
        }
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        let reasonStr = reason != nil ? String(data: reason!, encoding: .utf8) : nil
        DispatchQueue.main.async {
            self.delegate?.signalingClient(self, didReceiveEvent: .disconnected(reason: reasonStr))
        }
        scheduleReconnect()
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.parseIncomingText(text)
                case .data(let data):
                    DispatchQueue.main.async {
                        self.delegate?.signalingClient(self, didReceiveEvent: .binaryAudioReceived(data: data))
                    }
                @unknown default:
                    break
                }
                self.listenForMessages()

            case .failure(let error):
                self.isConnected = false
                DispatchQueue.main.async {
                    self.delegate?.signalingClient(self, didReceiveEvent: .disconnected(reason: error.localizedDescription))
                }
                self.scheduleReconnect()
            }
        }
    }

    private func scheduleReconnect() {
        DispatchQueue.main.async {
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                guard let self = self, !self.isConnected else { return }
                self.connect(serverUrl: self.serverUrl, userId: self.myUserId, deviceId: self.deviceId, displayName: self.myDisplayName)
            }
        }
    }

    private func parseIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        DispatchQueue.main.async {
            switch type {
            case "registered":
                break

            case "online_users":
                if let userDicts = json["users"] as? [[String: Any]] {
                    let users = userDicts.compactMap { d -> OnlineUserInfo? in
                        guard let uId = d["userId"] as? String else { return nil }
                        let dName = d["displayName"] as? String ?? uId
                        let plat = d["platform"] as? String ?? "unknown"
                        return OnlineUserInfo(userId: uId, displayName: dName, platform: plat)
                    }
                    self.delegate?.signalingClient(self, didReceiveEvent: .onlineUsers(users: users))
                }

            case "call_offer":
                if let callId = json["callId"] as? String,
                   let callerId = json["callerId"] as? String,
                   let callerPublicKey = json["callerPublicKey"] as? String {
                    let codec = json["audioCodec"] as? String ?? "opus"
                    self.delegate?.signalingClient(self, didReceiveEvent: .incomingCall(
                        callId: callId,
                        callerId: callerId,
                        callerPublicKey: callerPublicKey,
                        audioCodec: codec
                    ))
                }

            case "call_ringing":
                if let callId = json["callId"] as? String {
                    self.delegate?.signalingClient(self, didReceiveEvent: .ringing(callId: callId))
                }

            case "call_answer":
                if let callId = json["callId"] as? String,
                   let accepted = json["accepted"] as? Bool {
                    if accepted, let pubKey = json["calleePublicKey"] as? String {
                        self.delegate?.signalingClient(self, didReceiveEvent: .callAccepted(callId: callId, calleePublicKey: pubKey))
                    } else {
                        let reason = json["reason"] as? String
                        self.delegate?.signalingClient(self, didReceiveEvent: .callRejected(callId: callId, reason: reason))
                    }
                }

            case "relay_response":
                if let callId = json["callId"] as? String,
                   let host = json["relayHost"] as? String,
                   let port = json["relayPort"] as? Int,
                   let sessId = json["sessionId"] as? Int64,
                   let token = json["token"] as? String {
                    self.delegate?.signalingClient(self, didReceiveEvent: .relayInfo(
                        callId: callId,
                        host: host,
                        port: port,
                        sessionId: sessId,
                        token: token
                    ))
                }

            case "call_end":
                if let callId = json["callId"] as? String {
                    let reason = json["reason"] as? String ?? "hangup"
                    self.delegate?.signalingClient(self, didReceiveEvent: .callEnded(callId: callId, reason: reason))
                }

            case "error":
                let msg = json["message"] as? String ?? "Error"
                self.delegate?.signalingClient(self, didReceiveEvent: .error(message: msg))

            default:
                break
            }
        }
    }

    public func sendCallOffer(callId: String, callerId: String, calleeId: String, callerPublicKey: String) {
        let dict: [String: Any] = [
            "type": "call_offer",
            "callId": callId,
            "callerId": callerId,
            "calleeId": calleeId,
            "callerPublicKey": callerPublicKey,
            "audioCodec": "opus",
            "directP2PPreferred": true
        ]
        sendJson(dict)
    }

    public func sendCallRinging(callId: String, callerId: String, calleeId: String) {
        let dict: [String: Any] = [
            "type": "call_ringing",
            "callId": callId,
            "callerId": callerId,
            "calleeId": calleeId
        ]
        sendJson(dict)
    }

    public func sendCallAnswer(callId: String, callerId: String, calleeId: String, calleePublicKey: String?, accepted: Bool, reason: String? = nil) {
        var dict: [String: Any] = [
            "type": "call_answer",
            "callId": callId,
            "callerId": callerId,
            "calleeId": calleeId,
            "accepted": accepted
        ]
        if let pubKey = calleePublicKey { dict["calleePublicKey"] = pubKey }
        if let r = reason { dict["reason"] = r }
        sendJson(dict)
    }

    public func requestRelay(callId: String, userId: String) {
        let dict: [String: Any] = [
            "type": "relay_request",
            "callId": callId,
            "userId": userId
        ]
        sendJson(dict)
    }

    public func sendCallEnd(callId: String, fromUserId: String, toUserId: String, reason: String = "hangup") {
        let dict: [String: Any] = [
            "type": "call_end",
            "callId": callId,
            "fromUserId": fromUserId,
            "toUserId": toUserId,
            "reason": reason
        ]
        sendJson(dict)
    }

    public func sendAudioBinary(_ data: Data) {
        webSocketTask?.send(.data(data)) { _ in }
    }

    private func sendJson(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }
}
