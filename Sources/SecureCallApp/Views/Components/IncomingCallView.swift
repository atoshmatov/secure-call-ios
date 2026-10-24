import SwiftUI

public struct IncomingCallView: View {
    public let callerId: String
    public let onAccept: () -> Void
    public let onDecline: () -> Void

    @State private var pulse = false

    public init(callerId: String, onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        self.callerId = callerId
        self.onAccept = onAccept
        self.onDecline = onDecline
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                // E2EE Badge
                HStack(spacing: 6) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.nordicEmerald)

                    Text("KIRUVCHI XAVFSIZ QO'NG'IROQ")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.nordicEmerald)
                        .tracking(0.8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.nordicEmeraldMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.nordicEmerald.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Avatar with Pulse
                ZStack {
                    Circle()
                        .fill(Color.nordicEmerald.opacity(0.08))
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                    Circle()
                        .fill(Color.premiumCardElevated)
                        .frame(width: 84, height: 84)
                        .overlay(
                            Circle()
                                .stroke(Color.premiumBorder, lineWidth: 1.5)
                        )

                    Image(systemName: "person.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.textPrimary)
                }
                .padding(.top, 4)

                VStack(spacing: 4) {
                    Text(callerId)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.textPrimary)

                    Text("End-to-End Encrypted (X25519 + ChaCha20)")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }

                // Action Buttons
                HStack(spacing: 48) {
                    // Decline
                    Button(action: onDecline) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 62, height: 62)
                            .background(Color.velvetRose)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                            )
                    }

                    // Accept
                    Button(action: onAccept) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 62, height: 62)
                            .background(Color.nordicEmerald)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.premiumBorderSubtle, lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 8)
            }
            .padding(26)
            .background(Color.premiumCard)
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.premiumBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .padding(.horizontal, 28)
        }
        .onAppear {
            pulse = true
        }
    }
}
