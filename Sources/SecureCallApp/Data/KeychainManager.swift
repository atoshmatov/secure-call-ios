import Foundation
import Security

/// Apple Keychain orqali apparat darajasida shifrlangan doimiy xotira (Hardware-Backed Secure Storage).
/// UserDefaults o'rniga eng xavfsiz va zamonaviy yechim hisoblanadi.
public final class KeychainManager {

    public static let shared = KeychainManager()

    private let service = "uz.safecity.securecall.identity"

    private let keyUserId = "userId"
    private let keyDisplayName = "displayName"
    private let keyDeviceId = "deviceId"

    private init() {}

    public func getOrCreateIdentity() -> (userId: String, displayName: String, deviceId: String) {
        var currentUserId = get(key: keyUserId)
        var currentDisplayName = get(key: keyDisplayName)
        var currentDeviceId = get(key: keyDeviceId)

        if currentUserId == nil || currentUserId!.isEmpty {
            let shortId = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6).lowercased()
            let newId = "usr_\(shortId)"
            save(key: keyUserId, value: newId)
            currentUserId = newId
        }

        if currentDisplayName == nil || currentDisplayName!.isEmpty {
            let defaultName = "Apple Foydalanuvchi"
            save(key: keyDisplayName, value: defaultName)
            currentDisplayName = defaultName
        }

        if currentDeviceId == nil || currentDeviceId!.isEmpty {
            let newDevice = UUID().uuidString
            save(key: keyDeviceId, value: newDevice)
            currentDeviceId = newDevice
        }

        return (currentUserId!, currentDisplayName!, currentDeviceId!)
    }

    public func updateUserId(_ newId: String) {
        let trimmed = newId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty {
            save(key: keyUserId, value: trimmed)
        }
    }

    public func updateDisplayName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            save(key: keyDisplayName, value: trimmed)
        }
    }

    public func regenerateUserId() -> String {
        let shortId = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6).lowercased()
        let newId = "usr_\(shortId)"
        save(key: keyUserId, value: newId)
        return newId
    }

    // MARK: - Core Keychain Operations
    public func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Avval mavjud bo'lsa o'chirish
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    public func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    public func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
