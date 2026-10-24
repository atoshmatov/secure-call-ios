import SwiftUI

public struct TechnicalStatsView: View {
    public let sessionId: Int64
    public let sasHex: String
    public let packetsSent: UInt64
    public let packetsReceived: UInt64
    public let onDismiss: () -> Void

    public init(sessionId: Int64, sasHex: String, packetsSent: UInt64, packetsReceived: UInt64, onDismiss: @escaping () -> Void) {
        self.sessionId = sessionId
        self.sasHex = sasHex
        self.packetsSent = packetsSent
        self.packetsReceived = packetsReceived
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Xavfsizlik va Tarmoq Parametrlari")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.textPrimary)

            VStack(spacing: 8) {
                statRow(label: "Shifrlash (Cipher):", value: "ChaCha20-Poly1305 (256-bit AEAD)")
                statRow(label: "Kalit almashinuvi:", value: "Curve25519 (X25519 ECDH)")
                statRow(label: "KDF algoritmi:", value: "HKDF-SHA256")
                statRow(label: "SAS Fingerprint:", value: sasHex.uppercased())
                statRow(label: "Audio formati:", value: "16kHz Mono 16-bit PCM (20ms)")
                statRow(label: "Transport:", value: "Dual (UDP 50000 + WS Binary 8080)")
                statRow(label: "Sessiya ID:", value: "#\(sessionId)")
                statRow(label: "Yuborilgan paketlar:", value: "\(packetsSent) ta (~\(packetsSent * 640 / 1024) KB)")
                statRow(label: "Qabul qilingan paketlar:", value: "\(packetsReceived) ta")
                statRow(label: "Anti-Replay himoyasi:", value: "Faol (96-bit Counter)")
            }

            Button(action: onDismiss) {
                Text("Yopish")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.premiumCardElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding(22)
        .background(Color.premiumCard)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.premiumBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.horizontal, 24)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.nordicEmerald)
        }
    }
}
