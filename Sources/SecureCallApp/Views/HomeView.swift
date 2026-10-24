import SwiftUI

public struct HomeView: View {
    @StateObject public var viewModel = CallViewModel()

    @State private var targetUserId: String = ""
    @State private var showSettings: Bool = false
    @State private var tempUrl: String = ""

    private let presetContacts = ["inspector_02", "duty_officer", "patrol_car_1", "central_station"]

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
                .padding(.vertical, 14)

                ScrollView {
                    VStack(spacing: 18) {
                        // 1. Mening Qurilmam va Status Kartasi
                        VStack(spacing: 16) {
                            HStack {
                                Text("Mening Qurilmam")
                                    .font(.system(size: 16, weight: .semibold))
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
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Foydalanuvchi ID")
                                        .font(.system(size: 12))
                                        .foregroundColor(.textSecondary)

                                    Text(viewModel.myUserId)
                                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.textPrimary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("X25519 Efemer Kalit")
                                        .font(.system(size: 12))
                                        .foregroundColor(.textSecondary)

                                    Text(viewModel.publicKeyPreview)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.premiumCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.premiumBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22))

                        // 2. Yangi Qo'ng'iroq Boshlash Kartasi
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Xavfsiz Qo'ng'iroq")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.textPrimary)

                            // Input Field
                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.sapphireBlue)
                                    .font(.system(size: 15))

                                TextField("Qabul qiluvchi ID si", text: $targetUserId)
                                    .foregroundColor(.textPrimary)
                                    .font(.system(size: 14))
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(Color.premiumSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                            Text("Tezkor tanlash:")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(presetContacts, id: \.self) { contact in
                                        Button(action: { targetUserId = contact }) {
                                            Text(contact)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(.textPrimary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.premiumCardElevated)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }

                            // Start Call Button
                            Button(action: {
                                if !targetUserId.trimmingCharacters(in: .whitespaces).isEmpty {
                                    viewModel.startOutgoingCall(targetUserId: targetUserId.trimmingCharacters(in: .whitespaces))
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Qo'ng'iroq Boshlash")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(viewModel.isConnected && !targetUserId.isEmpty ? Color.sapphireBlue : Color.premiumCardElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(!viewModel.isConnected || targetUserId.isEmpty)
                        }
                        .padding(20)
                        .background(Color.premiumCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.premiumBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22))

                        // 3. E2EE Xavfsizlik Kafolati (Subtle Luxury Info)
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.nordicEmerald)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nol Bilim Kafolati (Zero-Knowledge)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.textPrimary)

                                Text("Har bir qo'ng'iroqda alohida efemer X25519 kalit generatsiya qilinadi. Audio oqim ChaCha20-Poly1305 bilan qurilmada shifrlanadi. Server paketlarni ocha olmaydi.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.premiumSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.premiumBorderSubtle, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }

            // Incoming Call Sheet / Modal
            if let offer = viewModel.incomingOffer {
                IncomingCallView(
                    callerId: offer.callerId,
                    onAccept: { viewModel.acceptIncomingCall() },
                    onDecline: { viewModel.declineIncomingCall() }
                )
            }

            // Fullscreen Active Call
            if viewModel.activeCall != nil {
                CallView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.connect()
        }
    }
}
