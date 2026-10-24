import SwiftUI

public struct SasVerificationView: View {
    public let emojis: [String]

    public init(emojis: [String]) {
        self.emojis = emojis
    }

    public var body: some View {
        VStack(spacing: 12) {
            // E2EE Verified Pill Badge
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.nordicEmerald)

                Text("E2EE XAVFSIZLIGI TASDIQLANGAN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.nordicEmerald)
                    .tracking(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.nordicEmeraldMuted)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.nordicEmerald.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // 4 ta SAS Emojilar bloki (Luxury Frosted Disks)
            HStack(spacing: 12) {
                ForEach(emojis.prefix(4), id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 26))
                        .frame(width: 54, height: 54)
                        .background(Color.premiumCardElevated)
                        .overlay(
                            Circle()
                                .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                        )
                        .clipShape(Circle())
                }
            }
            .padding(.top, 2)

            Text("Ushbu 4 ta emojini suhbatdoshingiz bilan solishtiring. Bir xil bo'lsa, oraliqda hech kim tinglay olmaydi.")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.premiumCard)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.premiumBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
