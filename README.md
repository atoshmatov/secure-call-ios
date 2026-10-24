# 🛡️ SecureCall iOS (End-to-End Encrypted Voice Calling)

Telegram va Signal uslubidagi **to'liq shifrlangan (E2EE)**, Apple apparat xavfsizligi (`CryptoKit`) va zamonaviy **SwiftUI** asosida yaratilgan premium xavfsiz ovozli qo'ng'iroqlar mijozi.

Ilova Android versiyasi ([`secure-call-android`](https://github.com/atoshmatov/secure-call-android)) bilan **100% kriptografik va vizual uyg'unlikka** ega bo'lib, bir xil **Premium Dark Obsidian (Charcoal & Royal Sapphire)** dizayn tilida ishlab chiqilgan.

---

## 🚀 Asosiy Texnologiyalar va Imkoniyatlar

1. **Apple Native Kriptografiya (`CryptoKit`):**
   * **X25519 Ephemeral ECDH:** `Curve25519.KeyAgreement.PrivateKey` — har bir qo'ng'iroq uchun yangi efemer kalit generatsiya qilinadi.
   * **HKDF-SHA256:** `sharedSecret.hkdfDerivedSymmetricKey` — kiruvchi (`rxKey`) va chiquvchi (`txKey`) oqimlar uchun mustaqil 256-bitli kalitlar.
   * **ChaCha20-Poly1305 (256-bit AEAD):** `ChaChaPoly.seal` va `ChaChaPoly.open` — har bir 20ms audio paket apparat tezligida shifrlanadi.
   * **Replay Attack Himoyasi:** 96-bitli oshib boruvchi hisoblagich (Sequence Nonce).

2. **Anti-MITM (Man-in-the-Middle) SAS Tekshiruvi:**
   * Android bilan bir xil 64 ta tushunarli Emojilar lug'ati.
   * Ikkala qurilma ekranida bir xil **4 ta SAS Emoji** (masalan: 🛡️ 🚀 🔒 ⚡) chiqadi va ovoz orqali oraliq hujum yo'qligi tasdiqlanadi.

3. **Yuqori Sifatli Ovoz Tizimi (`AVAudioEngine`):**
   * 16kHz PCM (HD Voice) format.
   * Mikrofon yozish: `inputNode.installTap(onBus: 0)`.
   * Karnay ijrosi: `AVAudioPlayerNode` va `AVAudioSession` (.playAndRecord, .voiceChat).
   * Jonli mikrofon to'lqini (Amplitude Waveform) vizualizatsiyasi.

4. **Dual-Transport Aloqa:**
   * **UDP:** `Network.framework` (`NWConnection`).
   * **WebSocket Binary:** `URLSessionWebSocketTask` — NAT, firewall yoki tunnel orqali ham audio kafolatlangan holda o'tadi.

5. **Yagona Premium Dark UI (Unified Design System):**
   * Deep Space Charcoal (`#0C0E12`) foni.
   * Translucent Hairline Glass borderlar (`Color.white.opacity(0.1)`).
   * Royal Sapphire (`#3B82F6`) asosiy harakat rangi va Nordic Emerald (`#10B981`) xavfsizlik tasdiq indikatori.
   * Nojo'ya neon yoki o'yin uslubidagi ko'zni charchatuvchi nurlanishlardan xoli, sokin va hashamatli dizayn.

6. **Lokal Kontaktlar Kitobi va Qo'ng'iroqlar Tarixi (Zero-Knowledge):**
   * Do'stlarning Peer ID larini ism va monogram avatar bilan xavfsiz saqlash.
   * Oxirgi qo'ng'iroqlar tarixi (kiruvchi, chiquvchi, o'tkazib yuborilgan) va 1-bosishda (1-tap) tezkor qo'ng'iroq qilish.
   * O'z Peer ID sini bir bosishda xotiraga nusxalash (Copy ID).

---

## 📂 Loyiha Tuzilmasi

```text
secure-call-ios/
├── Package.swift                             # Swift Package Manager konfiguratsiyasi
├── Sources/SecureCallApp/
│   ├── App.swift                             # Asosiy kirish nuqtasi (@main)
│   ├── Crypto/
│   │   └── CryptoEngine.swift                # Apple CryptoKit (Curve25519, ChaChaPoly, HKDF, SAS)
│   ├── Audio/
│   │   └── AudioCallEngine.swift             # AVAudioEngine, 16kHz PCM, NWConnection UDP
│   ├── Data/
│   │   └── ContactsManager.swift             # Sandboxed JSON persistent xotira
│   ├── Models/
│   │   └── Models.swift                      # Contact va CallHistoryItem modellari
│   ├── Signaling/
│   │   └── SignalingClient.swift             # URLSessionWebSocketTask va signallashuv
│   ├── ViewModels/
│   │   └── CallViewModel.swift               # Qo'ng'iroq holati, vaqt va xavfsizlik konteksti
│   └── Views/
│       ├── Theme.swift                       # Premium Luxury ranglar palitrasi
│       ├── HomeView.swift                    # Bosh ekran, Kontaktlar & Tarix tablari
│       ├── CallView.swift                    # Faol qo'ng'iroq, vaqt, avatar, audio visualizer
│       └── Components/
│           ├── AddContactView.swift          # Yangi kontakt saqlash oynasi
│           ├── AudioVisualizerView.swift     # Jonli to'lqin barlari
│           ├── SasVerificationView.swift     # 4 ta Emojili SAS kartasi
│           ├── IncomingCallView.swift        # Kiruvchi qo'ng'iroq oynasi
│           └── TechnicalStatsView.swift      # Texnik parametrlar varaqasi
```

---

## 🛠️ Talablar va Ishga Tushirish

* **iOS Versiyasi:** iOS 16.0 yoki undan yangi.
* **Xcode:** Xcode 15.0+ (Swift 5.9+).
* **Mac OS:** macOS Ventura (13.0) yoki undan yangi.

### Xcode orqali ochish:
```bash
# Repozitoriyni klonlash
git clone https://github.com/atoshmatov/secure-call-ios.git
cd secure-call-ios

# Xcode bilan ochish
open Package.swift
```

---

## 🔗 Moslik (Cross-Platform Compatibility)

Ushbu mijoz Android mijoz va Ktor backend bilan 100% integratsiyalashgan:
* **Backend:** [https://github.com/atoshmatov/secure-call-back](https://github.com/atoshmatov/secure-call-back)
* **Android Client:** [https://github.com/atoshmatov/secure-call-android](https://github.com/atoshmatov/secure-call-android)

---

## 📄 Litsenziya

Apache License 2.0.
