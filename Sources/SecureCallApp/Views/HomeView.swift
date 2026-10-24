import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct HomeView: View {
    @StateObject public var viewModel = CallViewModel()

    @State private var targetUserId: String = ""
    @State private var showSettings: Bool = false
    @State private var tempUrl: String = ""
    @State private var selectedTab: Int = 0 // 0 = Kontaktlar, 1 = Tarix

    // Add contact sheet state
    @State private var showAddContact: Bool = false
    @State private var prefillPeerId: String = ""
    @State private var prefillName: String = ""

    @State private var showCopiedAlert: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.premiumBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top App Bar
                HStack {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.sapphireBlue.opacity(0.12))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.premiumBorder, lineWidth: 1)
                                )

                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.sapphireBlue)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("SecureCall")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.textPrimary)

                            Text("End-to-End Encrypted")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .tracking(0.5)
                        }
                    }

                    Spacer()

                    Button(action: {
                        tempUrl = viewModel.serverUrl
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                            .foregroundColor(.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                ScrollView {
                    VStack(spacing: 14) {
                        // 1. Mening Qurilmam va Status Kartasi
                        VStack(spacing: 14) {
                            HStack {
                                Text("Mening Qurilmam")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                // Online / Offline Badge
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(viewModel.isConnected ? Color.nordicEmerald : Color.velvetRose)
                                        .frame(width: 6, height: 6)

                                    Text(viewModel.isConnected ? "Online" : "Offline")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(viewModel.isConnected ? .nordicEmerald : .velvetRose)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(viewModel.isConnected ? Color.nordicEmeraldMuted : Color.velvetRoseMuted)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(viewModel.isConnected ? Color.nordicEmerald.opacity(0.3) : Color.velvetRose.opacity(0.3), lineWidth: 1)
                                raid: 0)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Foydalanuvchi ID")
                                        .font(.system(size: 11))
                                        .foregroundColor(.textSecondary)

                                    Button(action: {
                                        #if canImport(UIKit)
                                        UIPasteboard.general.string = viewModel.myUserId
                                        #endif
                                        showCopiedAlert = true
                                    }) {
                                        HStack(spacing: 6) {
                                            Text(viewModel.myUserId)
                                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                                .foregroundColor(.textPrimary)

                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 12))
                                                .foregroundColor(.sapphireBlue)
                                        }
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("X25519 Efemer Kalit")
                                        .font(.system(size: 11))
                                        .foregroundColor(.textSecondary)

                                    Text(viewModel.publicKeyPreview)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .padding(18)
                        .background(Color.premiumCard)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.premiumBorder, lineWidth: 1)
                        )

                        // 2. Tezkor Terish Maydoni
                        HStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.sapphireBlue)

                                TextField("ID kiriting...", text: $targetUserId)
                                    .font(.system(size: 15))
                                    .foregroundColor(.textPrimary)
                            }
                            .padding(12)
                            .background(Color.premiumSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                            )

                            Button(action: {
                                if !targetUserId.trimmingCharacters(in: .whitespaces).isEmpty {
                                    viewModel.startOutgoingCall(targetUserId: targetUserId.trimmingCharacters(in: .whitespaces))
                                }
                            }) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 46, height: 46)
                                    .background(isDialEnabled ? Color.nordicEmerald : Color.premiumSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(!isDialEnabled)
                        }
                        .padding(12)
                        .background(Color.premiumCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.premiumBorder, lineWidth: 1)
                        )

                        // 3. Segmented Tab Picker
                        Picker("", selection: $selectedTab) {
                            Text("Kontaktlar (\(viewModel.contacts.count))").tag(0)
                            Text("Tarix (\(viewModel.callHistory.count))").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.vertical, 4)

                        // 4. Tab Tarkibi
                        if selectedTab == 0 {
                            contactsSection
                        } else {
                            historySection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }

            // Kiruvchi qo'ng'iroq
            if let offer = viewModel.incomingOffer {
                IncomingCallView(
                    callerId: offer.callerId,
                    onAccept: { viewModel.acceptIncomingCall() },
                    onDecline: { viewModel.declineIncomingCall() }
                )
            }

            // Faol qo'ng'iroq ekrani
            if viewModel.activeCall != nil {
                CallView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.connect()
        }
        .sheet(isPresented: $showAddContact) {
            AddContactView(
                initialPeerId: prefillPeerId,
                initialName: prefillName,
                onSave: { name, peerId in
                    viewModel.saveContact(name: name, peerId: peerId)
                }
            )
        }
        .alert("Nusxalandi", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sizning ID raqamingiz xotiraga nusxalandi.")
        }
    }

    // MARK: - Contacts Section
    private var contactsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Saqlangan Do'stlar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)

                Spacer()

                Button(action: {
                    prefillPeerId = ""
                    prefillName = ""
                    showAddContact = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 13))
                        Text("+ Kontakt Qo'shish")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.sapphireBlue)
                }
            }
            .padding(.horizontal, 4)

            if viewModel.contacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 44))
                        .foregroundColor(.textTertiary)
                    Text("Kontaktlar ro'yxati bo'sh")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Text("Do'stlaringizning ID sini saqlab, bir bosishda qo'ng'iroq qiling")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                ForEach(viewModel.contacts) { contact in
                    contactRow(contact: contact)
                }
            }
        }
    }

    private func contactRow(contact: Contact) -> some View {
        let avatarColor = Color(hexString: contact.avatarColorHex)
        let initials = contactInitials(name: contact.name)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(avatarColor.opacity(0.18))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(avatarColor.opacity(0.4), lineWidth: 1)
                    )

                Text(initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(avatarColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text(contact.peerId)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Button(action: {
                viewModel.deleteContact(id: contact.id)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundColor(.textTertiary)
                    .frame(width: 32, height: 32)
            }

            Button(action: {
                viewModel.startOutgoingCall(targetUserId: contact.peerId)
            }) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15))
                    .foregroundColor(viewModel.isConnected ? .nordicEmerald : .textTertiary)
                    .frame(width: 38, height: 38)
                    .background(Color.nordicEmerald.opacity(0.15))
                    .clipShape(Circle())
            }
            .disabled(!viewModel.isConnected)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.premiumCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.premiumBorderSubtle, lineWidth: 1)
        )
    }

    // MARK: - History Section
    private var historySection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Oxirgi Qo'ng'iroqlar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)

                Spacer()

                if !viewModel.callHistory.isEmpty {
                    Button("Tarixni tozalash") {
                        viewModel.clearHistory()
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.velvetRose)
                }
            }
            .padding(.horizontal, 4)

            if viewModel.callHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 44))
                        .foregroundColor(.textTertiary)
                    Text("Qo'ng'iroqlar tarixi bo'sh")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
            } else {
                ForEach(viewModel.callHistory) { item in
                    historyRow(item: item)
                }
            }
        }
    }

    private func historyRow(item: CallHistoryItem) -> some View {
        let (iconName, iconColor) = directionInfo(item.direction)
        let isSaved = viewModel.contacts.contains(where: { $0.peerId.caseInsensitiveCompare(item.peerId) == .orderedSame })

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.peerName ?? item.peerId)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Text("\(formatDate(item.timestamp)) • \(formatDuration(item.durationSeconds, direction: item.direction))")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if !isSaved {
                Button(action: {
                    prefillPeerId = item.peerId
                    prefillName = ""
                    showAddContact = true
                }) {
                    Text("+ Saqlash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.sapphireBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                        )
                }
            }

            Button(action: {
                viewModel.startOutgoingCall(targetUserId: item.peerId)
            }) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15))
                    .foregroundColor(viewModel.isConnected ? .nordicEmerald : .textTertiary)
                    .frame(width: 38, height: 38)
                    .background(Color.nordicEmerald.opacity(0.15))
                    .clipShape(Circle())
            }
            .disabled(!viewModel.isConnected)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.premiumCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.premiumBorderSubtle, lineWidth: 1)
        )
    }

    private var isDialEnabled: Bool {
        viewModel.isConnected && !targetUserId.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func contactInitials(name: String) -> String {
        let parts = name.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
        if parts.count >= 2, let first = parts.first?.prefix(1), let second = parts[1].prefix(1) {
            return "\(first)\(second)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func directionInfo(_ direction: CallDirection) -> (String, Color) {
        switch direction {
        case .incoming:
            return ("phone.arrow.down.left.fill", .nordicEmerald)
        case .outgoing:
            return ("phone.arrow.up.right.fill", .sapphireBlue)
        case .missed:
            return ("phone.arrow.down.left.fill", .velvetRose)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MMM, HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int, direction: CallDirection) -> String {
        if direction == .missed {
            return "O'tkazib yuborilgan"
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
