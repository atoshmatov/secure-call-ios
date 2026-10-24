import Foundation
import AVFoundation
import CryptoKit
import Network

public final class AudioCallEngine {

    public static let sampleRate: Double = 16000.0
    public static let frameSizeMs: Double = 20.0
    public static let samplesPerFrame = Int(sampleRate * frameSizeMs / 1000.0) // 320
    public static let bytesPerFrame = samplesPerFrame * 2 // 640 bytes (PCM 16-bit)

    public static let magic1: UInt8 = 0x53 // 'S'
    public static let magic2: UInt8 = 0x43 // 'C'

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?

    private var nwConnection: NWConnection?
    private var isRunning = false
    public var isMuted = false
    public var isSpeakerOn = false

    private var sequenceNumber: UInt64 = 1
    public var packetsSent: UInt64 = 0
    public var packetsReceived: UInt64 = 0

    private var currentRxKey: SymmetricKey?
    private var onSendWsAudio: ((Data) -> Void)?

    public var onAmplitudeChanged: ((Float) -> Void)?

    private let audioQueue = DispatchQueue(label: "uz.safecity.securecall.audio", qos: .userInteractive)

    public init() {
        self.audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: AudioCallEngine.sampleRate, channels: 1, interleaved: true)
    }

    public func startCallAudio(
        relayHost: String,
        relayPort: Int,
        sessionId: Int64,
        isCaller: Bool,
        txKey: SymmetricKey,
        rxKey: SymmetricKey,
        onSendWsAudio: @escaping (Data) -> Void
    ) {
        stopCallAudio()
        self.isRunning = true
        self.currentRxKey = rxKey
        self.onSendWsAudio = onSendWsAudio

        let senderType: UInt8 = isCaller ? 0x01 : 0x02

        // 1. UDP NWConnection tayyorlash
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(relayHost), port: NWEndpoint.Port(rawValue: UInt16(relayPort))!)
        let params = NWParameters.udp
        let connection = NWConnection(to: endpoint, using: params)
        self.nwConnection = connection

        connection.stateUpdateHandler = { state in
            if case .ready = state {
                self.receiveUdpPacket()
            }
        }
        connection.start(queue: audioQueue)

        // 2. AVAudioSession sozlash
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setPreferredSampleRate(AudioCallEngine.sampleRate)
            try session.setPreferredIOBufferDuration(0.02) // 20ms
            try session.setActive(true)
        } catch {}

        // 3. AVAudioEngine (Mikrofon va Karnay)
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        guard let format = audioFormat else { return }
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)

        // Mikrofon yozish
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(AudioCallEngine.samplesPerFrame), format: inputFormat) { [weak self] buffer, time in
            guard let self = self, self.isRunning else { return }
            self.processMicrophoneBuffer(buffer: buffer, sessionId: sessionId, senderType: senderType, txKey: txKey)
        }

        do {
            try engine.start()
            player.play()
            self.audioEngine = engine
            self.playerNode = player
        } catch {}
    }

    private func processMicrophoneBuffer(buffer: AVAudioPCMBuffer, sessionId: Int64, senderType: UInt8, txKey: SymmetricKey) {
        guard let channelData = buffer.int16ChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        if frameLength == 0 { return }

        var pcmData = Data(bytes: channelData[0], count: frameLength * 2)

        if isMuted {
            pcmData.resetBytes(in: 0..<pcmData.count)
            DispatchQueue.main.async { self.onAmplitudeChanged?(0.0) }
        } else {
            calculateAmplitude(pcm: pcmData)
        }

        audioQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }

            self.sequenceNumber += 1
            let seq = self.sequenceNumber

            guard let encryptedPayload = try? CryptoEngine.encryptAudio(pcm: pcmData, key: txKey, seq: seq) else { return }

            // Maxsus paket: Magic(2B) + SessionId(8B) + SenderType(1B) + Seq(4B) + Payload
            var packet = Data()
            packet.append(AudioCallEngine.magic1)
            packet.append(AudioCallEngine.magic2)

            var beSession = sessionId.bigEndian
            packet.append(Data(bytes: &beSession, count: 8))

            packet.append(senderType)

            var beSeq = UInt32(seq).bigEndian
            packet.append(Data(bytes: &beSeq, count: 4))

            packet.append(encryptedPayload)

            // A) UDP orqali yuborish
            self.nwConnection?.send(content: packet, completion: .contentProcessed { _ in })

            // B) WebSocket orqali yuborish (Dual-transport)
            self.onSendWsAudio?(packet)

            self.packetsSent += 1
        }
    }

    public func handleIncomingPacketBytes(_ data: Data) {
        audioQueue.async { [weak self] in
            guard let self = self, self.isRunning, data.count >= 15 else { return }

            let m1 = data[0]
            let m2 = data[1]
            guard m1 == AudioCallEngine.magic1, m2 == AudioCallEngine.magic2 else { return }

            let seqData = data.subdata(in: 11..<15)
            let seq = UInt64(seqData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

            let cipherData = data.subdata(in: 15..<data.count)

            guard let rxKey = self.currentRxKey,
                  let decryptedPcm = try? CryptoEngine.decryptAudio(cipherData: cipherData, key: rxKey, seq: seq) else { return }

            self.playPcmData(decryptedPcm)
            self.packetsReceived += 1
        }
    }

    private func playPcmData(_ pcm: Data) {
        guard let format = audioFormat, let player = playerNode else { return }

        let frameCount = AVAudioFrameCount(pcm.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        pcm.withUnsafeBytes { raw in
            if let base = raw.baseAddress, let channel = buffer.int16ChannelData {
                memcpy(channel[0], base, pcm.count)
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    private func receiveUdpPacket() {
        nwConnection?.receiveMessage { [weak self] content, context, isComplete, error in
            guard let self = self, self.isRunning else { return }
            if let data = content {
                self.handleIncomingPacketBytes(data)
            }
            if error == nil {
                self.receiveUdpPacket()
            }
        }
    }

    private func calculateAmplitude(pcm: Data) {
        pcm.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let pointer = raw.bindMemory(to: Int16.self).baseAddress else { return }
            let count = pcm.count / 2
            var maxAmp: Int16 = 0
            for i in 0..<count {
                let sample = abs(pointer[i])
                if sample > maxAmp { maxAmp = sample }
            }
            let normalized = min(max(Float(maxAmp) / 32768.0, 0.0), 1.0)
            DispatchQueue.main.async {
                self.onAmplitudeChanged?(normalized)
            }
        }
    }

    public func setMute(_ muted: Bool) {
        isMuted = muted
    }

    public func setSpeaker(_ speaker: Bool) {
        isSpeakerOn = speaker
        let port: AVAudioSession.PortOverride = speaker ? .speaker : .none
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(port)
    }

    public func stopCallAudio() {
        isRunning = false
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        playerNode?.stop()
        audioEngine = nil
        playerNode = nil

        nwConnection?.cancel()
        nwConnection = nil

        DispatchQueue.main.async {
            self.onAmplitudeChanged?(0.0)
        }
    }
}
