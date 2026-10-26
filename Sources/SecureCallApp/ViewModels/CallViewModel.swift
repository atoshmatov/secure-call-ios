import Foundation
import Combine
import UIKit

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
    public var isVideoCall: Bool = false
    public var isPeerVideoEnabled: Bool = false
}

public struct IncomingOfferState {
    public let callId: String
    public let callerId: String
    public let callerPublicKey: String
    public let isVideo: Bool
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

    // Video stream state
    @Published public var remoteVideoImage: UIImage? = nil
    @Published public var localVideoImage: UIImage? = nil
    @Published public var isVideoEnabled: Bool = false
    @Published public var isFrontCamera: Bool = true
    @Published public var videoFps: Int = 0

    public let contactsManager = ContactsManager()
    @Published public var contacts: [Contact] = []
    @Published public var callHistory: [CallHistoryItem] = []
    @Published public var onlineUsers: [OnlineUserInfo] = []

    private let signalingClient = SignalingClient()
    private let audioEngine = AudioCallEngine()
    public let videoEngine = VideoCallEngine()

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

        self.audioEngine.onVideoPacketReceived = { [weak self] data in
            self?.videoEngine.handleIncomingVideoPacket(data)
        }

        videoEngine.$remoteVideoImage
            .receive(on: DispatchQueue.main)
            .assign(to: &$remoteVideoImage)

        videoEngine.$localVideoImage
            .receive(on: DispatchQueue.main)
            .assign(to: &$localVideoImage)

        videoEngine.$isVideoEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isVideoEnabled)

        videoEngine.$isFrontCamera
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFrontCamera)

        videoEngine.$videoFps
            .receive(on: DispatchQueue.main)
            .assign(to: &$videoFps)
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

    public func startOutgoingCall(targetUserId: String, isVideo: Bool = false) {
        let callId = UUID().uuidString
        generateFreshKeys()
        guard let keys = myEphemeralKeys else { return }

        activeCall = ActiveCallUiState(
            callId = callId,
            peerId: targetUserId,
            isCaller = true,
            callState = .calling,
            isVideoCall = isVideo
        )

        signalingClient.sendCallOffer(
            callId: callId,
            callerId: myUserId,
            calleeId: targetUserId,
            callerPublicKey: keys.publicKeyBase64,
            isVideo: isVideo
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
            peerId = offer.callerId,
            isCaller = false,
            callState = .encrypting,
            securityContext = secContext,
            isVideoCall = offer.isVideo,
            isPeerVideoEnabled = offer.isVideo
        )

        signalingClient.sendCallAnswer(
            callId: offer.callId,
            callerId: offer.callerId,
            calleeId: myUserId,
            calleePublicKey: keys.publicKeyBase64,
            accepted: true,
            isVideo: offer.isVideo
        )

        signalingClient.requestRelay(callId: offer.callId, userId: myUserId)
    }

    public func declineIncomingCall() {
        guard let offer = incomingOffer else { return }
        incomingOffer = nil

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
        videoEngine.stopSession()
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

    public func toggleVideo() {
        videoEngine.toggleVideo()
        guard var call = activeCall else { return }
        call.isVideoCall = call.isVideoCall || videoEngine.isVideoEnabled
        activeCall = call
        signalingClient.sendVideoState(
            callId: call.callId,
            fromUserId: myUserId,
            toUserId: call.peerId,
            videoEnabled: videoEngine.isVideoEnabled
        )
    }

    public func switchCamera() {
        videoEngine.switchCamera()
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

        case .incomingCall(let callId, let callerId, let callerPublicKey, _, let isVideo):
            incomingOffer = IncomingOfferState(callId: callId, callerId: callerId, callerPublicKey: callerPublicKey, isVideo: isVideo)
            signalingClient.sendCallRinging(callId: callId, callerId: myUserId, calleeId: callerId)

        case .ringing:
            if var call = activeCall {
                call.callState = .ringing
                activeCall = call
            }

        case .callAccepted(_, let calleePublicKey, let isVideo):
            handleCallAccepted(calleePublicKey: calleePublicKey, isVideo: isVideo)

        case .callRejected(_, let reason):
            endCall(reason: reason ?? "Rad etildi")

        case .videoStateChanged(let callId, _, let videoEnabled):
            if var call = activeCall, call.callId == callId {
                call.isPeerVideoEnabled = videoEnabled
                activeCall = call
            }

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

    private func handleCallAccepted(calleePublicKey: String, isVideo: Bool = false) {
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
        call.isVideoCall = call.isVideoCall || isVideo
        call.isPeerVideoEnabled = isVideo
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

        videoEngine.startSession(
            sessionId: sessionId,
            isCaller: call.isCaller,
            txKey: sec.txKey,
            rxKey: sec.rxKey,
            sender: { [weak self] packet in
                self?.audioEngine.sendVideoPacket(packet)
            }
        )
        if call.isVideoCall {
            videoEngine.setVideoEnabled(true)
        } else {
            videoEngine.setVideoEnabled(false)
        }

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
