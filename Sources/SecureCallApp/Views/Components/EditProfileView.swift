import SwiftUI

public struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    var currentDisplayName: String
    var currentUserId: String
    var onSave: (String, String) -> Void
    var onRegenerateId: () -> Void

    @State private var displayName: String = ""
    @State private var userId: String = ""

    public init(
        currentDisplayName: String,
        currentUserId: String,
        onSave: @escaping (String, String) -> Void,
        onRegenerateId: @escaping () -> Void
    ) {
        self.currentDisplayName = currentDisplayName
        self.currentUserId = currentUserId
        self.onSave = onSave
        self.onRegenerateId = onRegenerateId
        _displayName = State(initialValue: currentDisplayName)
        _userId = State(initialValue: currentUserId)
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

                    Text("Shaxsiy Identifikator")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button("Saqlash") {
                        let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
                        let trimmedId = userId.trimmingCharacters(in: .whitespaces).lowercased()
                        if !trimmedName.isEmpty && !trimmedId.isEmpty {
                            onSave(trimmedName, trimmedId)
                            dismiss()
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isSaveEnabled ? .nordicEmerald : .textTertiary)
                    .disabled(!isSaveEnabled)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Keychain orqali xavfsiz saqlanadi")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                VStack(spacing: 16) {
                    // Ko'rinadigan Ism
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ko'rinadigan Ism")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundColor(.sapphireBlue)
                                .frame(width: 20)

                            TextField("Ism kiriting", text: $displayName)
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

                    // User ID
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Noyob ID (Routing ID)")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)

                        HStack(spacing: 12) {
                            Image(systemName: "number")
                                .foregroundColor(.sapphireBlue)
                                .frame(width: 20)

                            TextField("ID kiriting", text: $userId)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(14)
                        .background(Color.premiumSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                        )
                    }

                    // Yangi tasodifiy ID generatsiya qilish
                    HStack {
                        Spacer()
                        Button(action: {
                            onRegenerateId()
                            dismiss()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13))
                                Text("Yangi ID generatsiya qilish")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.sapphireBlue)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    private var isSaveEnabled: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !userId.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
