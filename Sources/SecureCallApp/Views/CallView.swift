import SwiftUI

public struct CallView: View {
    @ObservedObject public var viewModel: CallViewModel

    @State private var pulse = false
    @State private var showStats = false
    @State private var isVideoSwapped = false

    public init(viewModel: CallViewModel) {
        self.viewModel = viewModel
    }

    private var hasRemote: Bool { viewModel.remoteVideoImage != nil }
    private var hasLocal: Bool { viewModel.localVideoImage != nil && viewModel.isVideoEnabled }

    private var fullScreenImage: UIImage? {
        if hasRemote && hasLocal {
            return isVideoSwapped ? viewModel.localVideoImage : viewModel.remoteVideoImage
        }
        return hasRemote ? viewModel.remoteVideoImage : (hasLocal ? viewModel.localVideoImage : nil)
    }

    private var pipImage: UIImage? {
        if hasRemote && hasLocal {
            return isVideoSwapped ? viewModel.remoteVideoImage : viewModel.localVideoImage
        }
        return nil
    }

    public var body: some View {
        ZStack {
            Color.premiumBg
                .ignoresSafeArea()

            // 1. To'liq ekrandagi video tasviri (Full-screen)
            if let fullImg = fullScreenImage {
                Image(uiImage: fullImg)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                // Qoramtir gradient (yozuvlar o'qilishi uchun)
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.65),
                        Color.clear,
                        Color.black.opacity(0.75)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            // 2. Suzuvchi PIP karta (bosilganda o'rnini almashtiradi)
            if let pipImg = pipImage {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isVideoSwapped.toggle()
                            }
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                Image(uiImage: pipImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 110, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.premiumBorder, lineWidth: 1.5)
                                    )

                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .padding(6)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 48)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
            }

            if let call = viewModel.activeCall {
                VStack {
                    // Header: Status dot and duration
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor(for: call.callState))
                                .frame(width: 7, height: 7)

                            Text(statusText(for: call.callState))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(statusColor(for: call.callState))
                        }

                        Text(call.peerId)
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.top, 28)

                    Spacer()

                    // Center: Avatar with subtle pulse ring (Faqat video bo'lmaganda)
                    if fullScreenImage == nil {
                        VStack(spacing: 20) {
                            ZStack {
                                if call.callState == .connected || call.callState == .ringing {
                                    Circle()
                                        .fill(call.callState == .connected ? Color.nordicEmerald.opacity(0.08) : Color.amberWarm.opacity(0.08))
                                        .frame(width: 160, height: 160)
                                        .scaleEffect(pulse ? 1.15 : 1.0)
                                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                                }

                                Circle()
                                    .fill(Color.premiumCard)
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Circle().stroke(Color.premiumBorder, lineWidth: 1)
                                    )

                                Image(systemName: "person.fill")
                                    .font(.system(size: 52))
                                    .foregroundColor(.textPrimary)
                            }

                            // Waveform visualizer
                            if call.callState == .connected {
                                AudioVisualizerView(amplitude: viewModel.micAmplitude, isMuted: viewModel.isMuted)
                                    .padding(.horizontal, 32)
                            }

                            // SAS Verification card
                            if let sec = call.securityContext, !sec.sasEmojis.isEmpty {
                                SasVerificationView(emojis: sec.sasEmojis)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }

                    Spacer()

                    // Bottom: Control Buttons
                    HStack(spacing: 20) {
                        // 1. Mute
                        Button(action: { viewModel.toggleMute() }) {
                            Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.isMuted ? .velvetRose : .textPrimary)
                                .frame(width: 52, height: 52)
                                .background(viewModel.isMuted ? Color.velvetRoseMuted : Color.premiumCardElevated)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                )
                        }

                        // 2. Video Toggle
                        Button(action: { viewModel.toggleVideo() }) {
                            Image(systemName: viewModel.isVideoEnabled ? "video.fill" : "video.slash.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.isVideoEnabled ? .sapphireBlue : .textPrimary)
                                .frame(width: 52, height: 52)
                                .background(viewModel.isVideoEnabled ? Color.sapphireBlue.opacity(0.25) : Color.premiumCardElevated)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                )
                        }

                        // 3. Hangup
                        Button(action: { viewModel.endCall() }) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 66, height: 66)
                                .background(Color.velvetRose)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                )
                        }

                        // 4. Speaker
                        Button(action: { viewModel.toggleSpeaker() }) {
                            Image(systemName: viewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.wave.1.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.isSpeakerOn ? .sapphireBlue : .textPrimary)
                                .frame(width: 52, height: 52)
                                .background(viewModel.isSpeakerOn ? Color.sapphireBlue.opacity(0.2) : Color.premiumCardElevated)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                )
                        }

                        // 5. Flip Camera (video bo'lganda) yoki Info (video o'chirilganda)
                        if viewModel.isVideoEnabled {
                            Button(action: { viewModel.switchCamera() }) {
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.textPrimary)
                                    .frame(width: 52, height: 52)
                                    .background(Color.premiumCardElevated)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                    )
                            }
                        } else {
                            Button(action: { showStats = true }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.textSecondary)
                                    .frame(width: 44, height: 44)
                            }
                        }
                    }
                    .padding(.bottom, 36)
                }
            }

            if showStats, let call = viewModel.activeCall {
                Color.black.opacity(0.65).ignoresSafeArea()
                TechnicalStatsView(
                    sessionId: call.sessionId,
                    sasHex: call.securityContext?.sasRawHex ?? "",
                    packetsSent: 0,
                    packetsReceived: 0,
                    onDismiss: { showStats = false }
                )
            }
        }
        .onAppear {
            pulse = true
        }
    }

    private func statusColor(for state: CallState) -> Color {
        switch state {
        case .connected: return .nordicEmerald
        case .ringing: return .amberWarm
        default: return .sapphireBlue
        }
    }

    private func statusText(for state: CallState) -> String {
        switch state {
        case .calling: return "Chaqirilmoqda..."
        case .ringing: return "Jiringlamoqda..."
        case .encrypting: return "E2EE Shifrlanmoqda..."
        case .connected:
            let mins = viewModel.callDurationSeconds / 60
            let secs = viewModel.callDurationSeconds % 60
            let videoTag = viewModel.remoteVideoImage != nil ? " • HD Video (\(viewModel.videoFps) FPS)" : (hasLocal ? " • HD Video" : "")
            return String(format: "Bog'landi: %02d:%02d%@", mins, secs, videoTag)
        case .ended: return "Qo'ng'iroq yakunlandi"
        }
    }
}
