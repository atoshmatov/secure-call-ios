import SwiftUI

public struct CallView: View {
    @ObservedObject public var viewModel: CallViewModel

    @State private var pulse = false
    @State private var showStats = false

    public init(viewModel: CallViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color.premiumBg
                .ignoresSafeArea()

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

                    // Center: Avatar with subtle pulse ring
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

                    Spacer()

                    // Bottom: Control Buttons
                    HStack(spacing: 28) {
                        // Mute
                        Button(action: { viewModel.toggleMute() }) {
                            Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.isMuted ? .velvetRose : .textPrimary)
                                .frame(width: 56, height: 56)
                                .background(viewModel.isMuted ? Color.velvetRoseMuted : Color.premiumCardElevated)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                )
                        }

                        // Hangup
                        Button(action: { viewModel.endCall() }) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 68, height: 68)
                                .background(Color.velvetRose)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                )
                        }

                        // Speaker
                        Button(action: { viewModel.toggleSpeaker() }) {
                            Image(systemName: viewModel.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.wave.1.fill")
                                .font(.system(size: 20))
                                .foregroundColor(viewModel.isSpeakerOn ? .sapphireBlue : .textPrimary)
                                .frame(width: 56, height: 56)
                                .background(viewModel.isSpeakerOn ? Color.sapphireBlue.opacity(0.2) : Color.premiumCardElevated)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                )
                        }

                        // Stats info
                        Button(action: { showStats = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 22))
                                .foregroundColor(.textSecondary)
                                .frame(width: 44, height: 44)
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
            let m = viewModel.callDurationSeconds / 60
            let s = viewModel.callDurationSeconds % 60
            return String(format: "Bog'landi: %02d:%02d", m, s)
        case .ended: return "Qo'ng'iroq yakunlandi"
        }
    }
}
