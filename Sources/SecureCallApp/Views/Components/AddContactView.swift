import SwiftUI

public struct AddContactView: View {
    @Environment(\.dismiss) private var dismiss

    var initialPeerId: String = ""
    var initialName: String = ""
    var onSave: (String, String) -> Void

    @State private var name: String = ""
    @State private var peerId: String = ""

    public init(initialPeerId: String = "", initialName: String = "", onSave: @escaping (String, String) -> Void) {
        self.initialPeerId = initialPeerId
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _peerId = State(initialValue: initialPeerId)
    }

    private var initials: String {
        let target = name.isEmpty ? peerId : name
        let parts = target.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
        if parts.count >= 2, let first = parts.first?.prefix(1), let second = parts[1].prefix(1) {
            return "\(first)\(second)".uppercased()
        }
        return String(target.prefix(2)).uppercased()
    }

    public var body: some View {
        ZStack {
            Color.premiumBg
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Button("Bekor qilish") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)

                    Spacer()

                    Text(initialName.isEmpty && initialPeerId.isEmpty ? "Yangi Kontakt" : "Kontaktni Saqlash")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button("Saqlash") {
                        if !name.trimmingCharacters(in: .whitespaces).isEmpty &&
                            !peerId.trimmingCharacters(in: .whitespaces).isEmpty {
                            onSave(name.trimmingCharacters(in: .whitespaces), peerId.trimmingCharacters(in: .whitespaces))
                            dismiss()
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isSaveEnabled ? .nordicEmerald : .textTertiary)
                    .disabled(!isSaveEnabled)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Avatar Monogram
                ZStack {
                    Circle()
                        .fill(Color.sapphireBlue.opacity(0.18))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(Color.sapphireBlue.opacity(0.4), lineWidth: 1.5)
                        )

                    Text(initials.isEmpty ? "?" : initials)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.sapphireBlue)
                }
                .padding(.top, 10)

                VStack(spacing: 14) {
                    // Ism Field
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .foregroundColor(.sapphireBlue)
                            .frame(width: 24)

                        TextField("Ism yoki taxallus", text: $name)
                            .foregroundColor(.textPrimary)
                    }
                    .padding(14)
                    .background(Color.premiumSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                    )

                    // Peer ID Field
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .foregroundColor(.sapphireBlue)
                            .frame(width: 24)

                        TextField("Qurilma / Peer ID", text: $peerId)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.textPrimary)
                    }
                    .padding(14)
                    .background(Color.premiumSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !peerId.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
