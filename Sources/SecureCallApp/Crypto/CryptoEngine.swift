import Foundation
import CryptoKit

public struct EphemeralKeys {
    public let privateKey: Curve25519.KeyAgreement.PrivateKey
    public let publicKey: Curve25519.KeyAgreement.PublicKey
    public let publicKeyBase64: String

    public init(privateKey: Curve25519.KeyAgreement.PrivateKey, publicKey: Curve25519.KeyAgreement.PublicKey, publicKeyBase64: String) {
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.publicKeyBase64 = publicKeyBase64
    }
}

public struct CallSecurityContext {
    public let sharedSecret: Data
    public let txKey: SymmetricKey
    public let rxKey: SymmetricKey
    public let sasEmojis: [String]
    public let sasRawHex: String

    public init(sharedSecret: Data, txKey: SymmetricKey, rxKey: SymmetricKey, sasEmojis: [String], sasRawHex: String) {
        self.sharedSecret = sharedSecret
        self.txKey = txKey
        self.rxKey = rxKey
        self.sasEmojis = sasEmojis
        self.sasRawHex = sasRawHex
    }
}

public enum CryptoEngine {

    // 64 ta tushunarli va farqlash oson bo'lgan Emoji ro'yxati (Android bilan 100% bir xil)
    public static let sasEmojis: [String] = [
        "🍋", "🚀", "🦊", "🍏", "🐬", "🦁", "⚡", "💎",
        "🍒", "🍇", "🔔", "🎯", "🎸", "🏀", "⚓", "🛸",
        "🍉", "🍓", "🦋", "🌸", "⭐", "🔥", "🛡️", "👑",
        "🍎", "🍍", "🥑", "🐯", "🐼", "🦄", "🌈", "🎈",
        "🚗", "✈️", "🚢", "🚲", "☕", "🍕", "🍦", "🍩",
        "⚽", "🎾", "🏆", "🎨", "🎤", "🎻", "🌙", "☀️",
        "🌊", "🌴", "🌵", "🍁", "🍄", "🐝", "🦉", "🐢",
        "🐙", "🦀", "🐠", "🎁", "🔑", "💡", "🔮", "🧭"
    ]

    // X.509 ASN.1 sarlavhasi (12 bayt) — Android KeyFactory bilan moslash uchun
    private static let x509Header = Data([
        0x30, 0x2a, 0x30, 0x05, 0x06, 0x03, 0x2b, 0x65, 0x6e, 0x03, 0x21, 0x00
    ])

    /// 1. Yangi bir martalik efemer X25519 kalit juftligini yaratadi
    public static func generateEphemeralKeyPair() -> EphemeralKeys {
        let priv = Curve25519.KeyAgreement.PrivateKey()
        let pub = priv.publicKey
        let rawBytes = pub.rawRepresentation

        // Android bilan 100% mos bo'lishi uchun standart X.509 formatda Base64 qiladi
        let fullX509 = x509Header + rawBytes
        let base64 = fullX509.base64EncodedString()

        return EphemeralKeys(privateKey: priv, publicKey: pub, publicKeyBase64: base64)
    }

    /// 2. Qarshi tomondan olingan Base64 ochiq kalitni (32B raw yoki 44B X.509) tiklaydi
    public static func decodePublicKey(base64: String) throws -> Curve25519.KeyAgreement.PublicKey {
        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "CryptoEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Base64 public key"])
        }

        let rawBytes: Data
        if data.count == 32 {
            rawBytes = data
        } else if data.count >= 44 {
            // X.509 formatdagi oxirgi 32 bayt
            rawBytes = data.suffix(32)
        } else {
            throw NSError(domain: "CryptoEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Public key length invalid: \(data.count) bytes"])
        }

        return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: rawBytes)
    }

    /// 3. ECDH Shared Secret va HKDF-SHA256 orqali sessiya kalitlarini hosil qilish
    public static func deriveSecurityContext(
        myPrivate: Curve25519.KeyAgreement.PrivateKey,
        peerPublic: Curve25519.KeyAgreement.PublicKey,
        isCaller: Bool
    ) throws -> CallSecurityContext {
        // ECDH orqali 256-bitli umumiy sir
        let sharedSecret = try myPrivate.sharedSecretFromKeyAgreement(with: peerPublic)

        // HKDF orqali Tx va Rx kalitlarni ajratish
        let infoCaller = "SafeCall-Caller-To-Callee".data(using: .utf8)!
        let infoCallee = "SafeCall-Callee-To-Caller".data(using: .utf8)!

        let keyCallerToCallee = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: infoCaller,
            outputByteCount: 32
        )

        let keyCalleeToCaller = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: infoCallee,
            outputByteCount: 32
        )

        let txKey = isCaller ? keyCallerToCallee : keyCalleeToCaller
        let rxKey = isCaller ? keyCalleeToCaller : keyCallerToCallee

        // 4 ta SAS Emojilarni hosil qilish (4 bytes)
        let sasInfo = "SafeCall-SAS-Verification-V1".data(using: .utf8)!
        let sasKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: sasInfo,
            outputByteCount: 4
        )

        let sasBytes = sasKey.withUnsafeBytes { Data($0) }
        let emojis = sasBytes.map { byte -> String in
            let idx = Int(byte) % sasEmojis.count
            return sasEmojis[idx]
        }
        let sasHex = sasBytes.map { String(format: "%02x", $0) }.joined()

        let rawSecretData = sharedSecret.withUnsafeBytes { Data($0) }

        return CallSecurityContext(
            sharedSecret: rawSecretData,
            txKey: txKey,
            rxKey: rxKey,
            sasEmojis: emojis,
            sasRawHex: sasHex
        )
    }

    /// 4. ChaCha20-Poly1305 (256-bit AEAD) bilan audio freymni shifrlash
    public static func encryptAudio(pcm: Data, key: SymmetricKey, seq: UInt64) throws -> Data {
        let nonce = try createNonce(seq: seq)
        let sealedBox = try ChaChaPoly.seal(pcm, using: key, nonce: nonce)
        // Ciphertext + Poly1305 Tag
        return sealedBox.ciphertext + sealedBox.tag
    }

    /// 5. ChaCha20-Poly1305 bilan audio freymni shifrdan chiqarish
    public static func decryptAudio(cipherData: Data, key: SymmetricKey, seq: UInt64) throws -> Data {
        guard cipherData.count >= 16 else {
            throw NSError(domain: "CryptoEngine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Ciphertext too short"])
        }
        let nonce = try createNonce(seq: seq)
        let cipherText = cipherData.prefix(cipherData.count - 16)
        let tag = cipherData.suffix(16)

        let sealedBox = try ChaChaPoly.SealedBox(nonce: nonce, ciphertext: cipherText, tag: tag)
        return try ChaChaPoly.open(sealedBox, using: key)
    }

    /// 12-baytlik takrorlanmas Nonce (oxirgi 8 baytiga sequence raqami yoziladi)
    private static func createNonce(seq: UInt64) throws -> ChaChaPoly.Nonce {
        var bytes = [UInt8](repeating: 0, count: 12)
        let beSeq = seq.bigEndian
        withUnsafeBytes(of: beSeq) { raw in
            for i in 0..<8 {
                bytes[4 + i] = raw[i]
            }
        }
        return try ChaChaPoly.Nonce(data: Data(bytes))
    }
}
