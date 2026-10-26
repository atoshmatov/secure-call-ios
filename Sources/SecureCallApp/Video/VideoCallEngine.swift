import Foundation
import AVFoundation
import UIKit
import CryptoKit

public final class VideoCallEngine: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {

    public static let magic1: UInt8 = 0x53 // 'S'
    public static let magic2: UInt8 = 0x43 // 'C'
    public static let packetTypeVideo: UInt8 = 0x02
    public static let maxChunkSize = 1100

    @Published public var isVideoEnabled = false
    @Published public var isFrontCamera = true
    @Published public var remoteVideoImage: UIImage? = nil
    @Published public var localVideoImage: UIImage? = nil
    @Published public var videoFps = 0

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoQueue = DispatchQueue(label: "uz.safecity.securecall.video", qos: .userInteractive)

    private var activeSessionId: Int64 = 0
    private var isCaller = false
    private var currentTxKey: SymmetricKey?
    private var currentRxKey: SymmetricKey?
    private var packetSender: ((Data) -> Void)?
    private var isRunning = false

    private var frameCounter: UInt32 = 1

    private final class IncompleteFrame {
        let totalChunks: Int
        var chunks: [Int: Data] = [:]
        let createdAt = Date()

        init(totalChunks: Int) {
            self.totalChunks = totalChunks
        }
    }
    private var frameBuffers: [UInt32: IncompleteFrame] = [:]
    private var framesReceivedCount = 0
    private var lastFpsCalculationTime = Date()

    public override init() {
        super.init()
    }

    public func startSession(
        sessionId: Int64,
        isCaller: Bool,
        txKey: SymmetricKey,
        rxKey: SymmetricKey,
        sender: @escaping (Data) -> Void
    ) {
        self.activeSessionId = sessionId
        self.isCaller = isCaller
        self.currentTxKey = txKey
        self.currentRxKey = rxKey
        self.packetSender = sender
        self.isRunning = true
        self.frameBuffers.removeAll()
    }

    public func stopSession() {
        isRunning = false
        stopCamera()
        DispatchQueue.main.async {
            self.remoteVideoImage = nil
            self.localVideoImage = nil
            self.isVideoEnabled = false
        }
        frameBuffers.removeAll()
    }

    public func setVideoEnabled(_ enabled: Bool) {
        if enabled {
            if !isVideoEnabled {
                DispatchQueue.main.async { self.isVideoEnabled = true }
                startCamera()
            }
        } else {
            if isVideoEnabled {
                DispatchQueue.main.async {
                    self.isVideoEnabled = false
                    self.localVideoImage = nil
                }
                stopCamera()
            }
        }
    }

    public func toggleVideo() {
        setVideoEnabled(!isVideoEnabled)
    }

    public func switchCamera() {
        isFrontCamera.toggle()
        if isVideoEnabled {
            stopCamera()
            startCamera()
        }
    }

    public func startCamera() {
        videoQueue.async { [weak self] in
            guard let self = self else { return }

            let session = AVCaptureSession()
            session.sessionPreset = .vga640x480

            let position: AVCaptureDevice.Position = self.isFrontCamera ? .front : .back
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let input = try? AVCaptureDeviceInput(device: camera) else { return }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            output.setSampleBufferDelegate(self, queue: self.videoQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.startRunning()
            self.captureSession = session
            self.videoOutput = output
        }
    }

    public func stopCamera() {
        videoQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.videoOutput = nil
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRunning, isVideoEnabled,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        guard let jpegData = uiImage.jpegData(compressionQuality: 0.5) else { return }

        DispatchQueue.main.async {
            self.localVideoImage = uiImage
        }

        sendVideoFrame(jpegData)
    }

    private func sendVideoFrame(_ jpegData: Data) {
        guard let txKey = currentTxKey else { return }
        let senderType: UInt8 = isCaller ? 0x01 : 0x02

        frameCounter &+= 1
        let frameId = frameCounter
        let totalSize = jpegData.count
        let totalChunks = max(1, (totalSize + VideoCallEngine.maxChunkSize - 1) / VideoCallEngine.maxChunkSize)

        for chunkIdx in 0..<totalChunks {
            let offset = chunkIdx * VideoCallEngine.maxChunkSize
            let length = min(VideoCallEngine.maxChunkSize, totalSize - offset)
            let chunkData = jpegData.subdata(in: offset..<(offset + length))

            let chunkSeq = (UInt64(1) << 48) | (UInt64(frameId) << 16) | UInt64(chunkIdx)
            guard let encryptedChunk = try? CryptoEngine.encryptAudio(pcm: chunkData, key: txKey, seq: chunkSeq) else {
                continue
            }

            // Packet layout:
            // Magic(2B) + SessionId(8B) + SenderType(1B) + PacketType(1B: 0x02) + FrameId(4B) + ChunkIdx(2B) + TotalChunks(2B) + Payload
            var packet = Data()
            packet.append(VideoCallEngine.magic1)
            packet.append(VideoCallEngine.magic2)

            var beSession = activeSessionId.bigEndian
            packet.append(Data(bytes: &beSession, count: 8))

            packet.append(senderType)
            packet.append(VideoCallEngine.packetTypeVideo)

            var beFrameId = frameId.bigEndian
            packet.append(Data(bytes: &beFrameId, count: 4))

            var beChunkIdx = UInt16(chunkIdx).bigEndian
            packet.append(Data(bytes: &beChunkIdx, count: 2))

            var beTotalChunks = UInt16(totalChunks).bigEndian
            packet.append(Data(bytes: &beTotalChunks, count: 2))

            packet.append(encryptedChunk)

            packetSender?(packet)
        }
    }

    public func handleIncomingVideoPacket(_ data: Data) {
        guard data.count >= 20 else { return }

        let m1 = data[0]
        let m2 = data[1]
        guard m1 == VideoCallEngine.magic1, m2 == VideoCallEngine.magic2 else { return }

        let pType = data[11]
        guard pType == VideoCallEngine.packetTypeVideo else { return }

        let frameId = data.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let chunkIdx = Int(data.subdata(in: 16..<18).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
        let totalChunks = Int(data.subdata(in: 18..<20).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })

        let encryptedChunk = data.subdata(in: 20..<data.count)

        guard let rxKey = currentRxKey else { return }
        let chunkSeq = (UInt64(1) << 48) | (UInt64(frameId) << 16) | UInt64(chunkIdx)

        guard let decryptedChunk = try? CryptoEngine.decryptAudio(cipherData: encryptedChunk, key: rxKey, seq: chunkSeq) else {
            return
        }

        let buffer = frameBuffers[frameId] ?? IncompleteFrame(totalChunks: totalChunks)
        buffer.chunks[chunkIdx] = decryptedChunk
        frameBuffers[frameId] = buffer

        if buffer.chunks.count == buffer.totalChunks {
            frameBuffers.removeValue(forKey: frameId)

            var fullJpeg = Data()
            for i in 0..<buffer.totalChunks {
                guard let chunk = buffer.chunks[i] else { return }
                fullJpeg.append(chunk)
            }

            if let image = UIImage(data: fullJpeg) {
                DispatchQueue.main.async {
                    self.remoteVideoImage = image
                    self.framesReceivedCount += 1
                    self.updateFpsStats()
                }
            }

            // Clean up stale frame buffers (> 350ms)
            let now = Date()
            frameBuffers = frameBuffers.filter { now.timeIntervalSince($0.value.createdAt) < 0.35 }
        }
    }

    private func updateFpsStats() {
        let now = Date()
        let diff = now.timeIntervalSince(lastFpsCalculationTime)
        if diff >= 1.0 {
            videoFps = Int(Double(framesReceivedCount) / diff)
            framesReceivedCount = 0
            lastFpsCalculationTime = now
        }
    }
}
