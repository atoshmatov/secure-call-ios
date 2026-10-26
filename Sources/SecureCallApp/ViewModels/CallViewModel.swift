import Foundation
import Combine

public enum CallState {
    case calling
    case ringing
    case encrypting
    case connected
    case ended
}

public struct ActiveCallUiState {
    public let callId: String
    public let peerId: String
    public let isCaller: Bool
    public var callState: CallState
    public var securityContext: CallSecurityContext?
    public var sessionId: Int64 = 0
    public var relayHost: String = ""
    public var relayPort: Int = 50000
}

public struct IncomingOfferState {
    public let callId: String
    public let callerId: String
    public let callerPublicKey: String
}

@MainActor
public final class CallViewModel: ObservableObject, SignalingClientDelegate {

    @Published public var myUserId: String = ""
    @Published public var displayName: String = ""
    @Published public var deviceId: String = ""
    @Published public var isConnected: Bool = false
    @Published public var serverUrl: String = "ws://127.0.0.1:8080/ws/signaling"
    @Published public var publicKeyPreview: String = "..."

    @Published public var activeCall: ActiveCallUiState?
    @Published public var incomingOffer: IncomingOfferState?
    @Published public var callDurationSeconds: Int = 0

    @Published public var micAmplitude: Float = 0.0
    @Published public var isMuted: Bool = false
    @Published public var isSpeakerOn: Bool = false

    public let contactsManager = ContactsManager()
    @Published public var contacts: [Contact] = []
    @Published public var callHistory: [CallHistoryItem] = []
    @Published public var onlineUsers: [OnlineUserInfo] = []

    private let signalingClient = SignalingClient()
    private let audioEngine = AudioCallEngine()
    private var myEphemeralKeys: EphemeralKeys?
    private var durationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        let identity = KeychainManager.shared.getOrCreateIdentity()
        self.myUserId = identity.userId
        self.displayName = identity.displayName
        self.deviceId = identity.deviceId

        self.signalingClient.delegate = self
        generateFreshKeys()

        // Sync contacts and history
        contactsManager.$contacts
            .receive(on: DispatchQueue.main)
            .assign(to: &$contacts)

        contactsManager.$callHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$callHistory)

        self.audioEngine.onAmplitudeChanged = { [weak self] amp in
            DispatchQueue.main.async {
                self?.micAmplitude = amp
            }
        }
    }

    public func updateDisplayName(_ newName: String) {
        displayName = newName
        KeychainManager.shared.updateDisplayName(newName)
        signalingClient.disconnect()
        connect()
    }

    public func updateUserId(_ newId: String) {
        myUserId = newId
        KeychainManager.shared.updateUserId(newId)
        signalingClient.disconnect()
        connect()
    }

    public func regenerateUserId() {
        let newId = KeychainManager.shared.regenerateUserId()
        myUserId = newId
        signalingClient.disconnect()
        connect()
    }

    public func connect() {
        signalingClient.connect(serverUrl: serverUrl, userId: myUserId, deviceId: deviceId, displayName: displayName)
    }

    public func updateServerUrl(_ newUrl: String) {
        serverUrl = newUrl
        signalingClient.disconnect()
        connect()
    }

    private func generateFreshKeys() {
        let keys = CryptoEngine.generateEphemeralKeyPair()
        myEphemeralKeys = keys
        publicKeyPreview = "\(keys.publicKeyBase64.prefix(8))..."
    }

    public func startOutgoingCall(targetUserId: String) {
        let callId = UUID().uuidString
        generateFreshKeys()
        guard let keys = myEphemeralKeys else { return }

        activeCall = ActiveCallUiState(
            callId = callId,
            peerId: targetUserId,
            isCaller: true,
            callState: .calling
        )

        signalingClient.sendCallOffer(
            callId: callId,
            callerId: myUserId,
            calleeId: targetUserId,
            callerPublicKey: keys.publicKeyBase64
        )
    }

    public func acceptIncomingCall() {
        guard let offer = incomingOffer else { return }
        incomingOffer = nil

        generateFreshKeys()
        guard let keys = myEphemeralKeys,
              let callerPubKey = try? CryptoEngine.decodePublicKey(base64: offer.callerPublicKey),
              let secContext = try? CryptoEngine.deriveSecurityContext(
                myPrivate: keys.privateKey,
                peerPublic: callerPubKey,
                isCaller: false
              ) else { return }

        activeCall = ActiveCallUiState(
            callId = offer.callId,
            peerId: offer.callerId,
            isCaller: false,
            callState: .encrypting,
            securityContext: secContext
        )

        signalingClient.sendCallAnswer(
            callId: offer.callId,
            callerId: offer.callerId,
            calleeId: myUserId,
            calleePublicKey: keys.publicKeyBase64,
            accepted: true
        )

        signalingClient.requestRelay(callId: offer.callId, userId: myUserId)
    }

    public func declineIncomingCall() {
        guard let offer = incomingOffer else { return }
        incomingOffer = nil

        // Tarixga o'tkazib yuborilgan deb yozish
        contactsManager.addCallRecord(peerId: offer.callerId, direction: .missed, durationSeconds: 0)

        signalingClient.sendCallAnswer(
            callId: offer.callId,
            callerId: offer.callerId,
            calleeId: myUserId,
            calleePublicKey: nil,
            accepted: false,
            reason: "busy"
        )
    }

    public func endCall(reason: String = "hangup") {
        if let call = activeCall {
            let dir: CallDirection = call.isCaller ? .outgoing : .incoming
            contactsManager.addCallRecord(peerId: call.peerId, direction: dir, durationSeconds: callDurationSeconds)
            signalingClient.sendCallEnd(callId: call.callId, fromUserId: myUserId, toUserId: call.peerId, reason: reason)
        }
        audioEngine.stopCallAudio()
        durationTimer?.invalidate()
        durationTimer = nil
        activeCall = nil
        callDurationSeconds = 0
        micAmplitude = 0.0
    }

    public func saveContact(name: String, peerId: String) {
        contactsManager.addOrUpdateContact(name: name, peerId: peerId)
    }

    public func deleteContact(id: String) {
        contactsManager.deleteContact(id: id)
    }

    public func clearHistory() {
        contactsManager.clearHistory()
    }

    public func getContactName(peerId: String) -> String? {
        return contactsManager.resolvePeerName(peerId: peerId)
    }

    public func toggleMute() {
        isMuted.toggle()
        audioEngine.setMute(isMuted)
    }

    public func toggleSpeaker() {
        isSpeakerOn.toggle()
        audioEngine.setSpeaker(isSpeakerOn)
    }

    // MARK: - SignalingClientDelegate
    public func signalingClient(_ client: SignalingClient, didReceiveEvent event: SignalingEvent) {
        switch event {
        case .connected:
            isConnected = true

        case .disconnected:
            isConnected = false
            if activeCall != nil {
                endCall(reason: "Server aloqasi uzildi")
            }

        case .onlineUsers(let users):
            self.onlineUsers = users.filter { $0.userId != self.myUserId }

        case .incomingCall(let callId, let callerId, let callerPublicKey, _):
            incomingOffer = IncomingOfferState(callId: callId, callerId: callerId, callerPublicKey: callerPublicKey)
            signalingClient.sendCallRinging(callId: callId, callerId: myUserId, calleeId: callerId)

        case .ringing:
            if var call = activeCall {
                call.callState = .ringing
                activeCall = call
            }

        case .callAccepted(_, let calleePublicKey):
            handleCallAccepted(calleePublicKey: calleePublicKey)

        case .callRejected(_, let reason):
            endCall(reason: reason ?? "Rad etildi")

        case .relayInfo(_, let host, let port, let sessionId, _):
            handleRelayInfo(host: host, port: port, sessionId: sessionId)

        case .binaryAudioReceived(let data):
            audioEngine.handleIncomingPacketBytes(data)

        case .callEnded(_, let reason):
            endCall(reason: reason)

        case .error:
            break
        }
    }

    private func handleCallAccepted(calleePublicKey: String) {
        guard var call = activeCall,
              let myKeys = myEphemeralKeys,
              let peerPublic = try? CryptoEngine.decodePublicKey(base64: calleePublicKey),
              let secContext = try? CryptoEngine.deriveSecurityContext(
                myPrivate: myKeys.privateKey,
                peerPublic: peerPublic,
                isCaller: true
              ) else { return }

        call.callState = .encrypting
        call.securityContext = secContext
        activeCall = call

        signalingClient.requestRelay(callId: call.callId, userId: myUserId)
    }

    private func handleRelayInfo(host: String, port: Int, sessionId: Int64) {
        guard var call = activeCall, let sec = call.securityContext else { return }

        call.callState = .connected
        call.sessionId = sessionId
        call.relayHost = host
        call.relayPort = port
        activeCall = call

        audioEngine.startCallAudio(
            relayHost: host,
            relayPort: port,
            sessionId: sessionId,
            isCaller: call.isCaller,
            txKey: sec.txKey,
            rxKey: sec.rxKey,
            onSendWsAudio: { [weak self] data in
                self?.signalingClient.sendAudioBinary(data)
            }
        )

        startTimer()
    }

    private func startTimer() {
        durationTimer?.invalidate()
        callDurationSeconds = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.callDurationSeconds += 1
            }
        }
    }
}
