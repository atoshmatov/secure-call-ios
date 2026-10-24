import Foundation
import Combine

@MainActor
public final class ContactsManager: ObservableObject {

    @Published public private(set) var contacts: [Contact] = []
    @Published public private(set) var callHistory: [CallHistoryItem] = []

    private let fileManager = FileManager.default
    private let avatarColors = [
        "#3B82F6", "#10B981", "#8B5CF6", "#F59E0B", "#EC4899", "#06B6D4", "#6366F1"
    ]

    private var contactsFileURL: URL {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("secure_contacts.json")
    }

    private var historyFileURL: URL {
        let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return directory.appendingPathComponent("call_history.json")
    }

    public init() {
        loadData()
    }

    private func loadData() {
        // Load contacts
        if let data = try? Data(contentsOf: contactsFileURL),
           let loaded = try? JSONDecoder().decode([Contact].self, from: data) {
            self.contacts = loaded
        } else {
            // Default initial contacts
            let defaults = [
                Contact(name: "Navbatchi qism", peerId: "duty_officer", avatarColorHex: "#3B82F6"),
                Contact(name: "Patrul 01", peerId: "patrol_car_1", avatarColorHex: "#10B981")
            ]
            self.contacts = defaults
            saveContacts()
        }

        // Load call history
        if let data = try? Data(contentsOf: historyFileURL),
           let loaded = try? JSONDecoder().decode([CallHistoryItem].self, from: data) {
            self.callHistory = loaded
        } else {
            self.callHistory = []
        }
    }

    public func addOrUpdateContact(name: String, peerId: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPeer = peerId.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = contacts.firstIndex(where: { $0.peerId.caseInsensitiveCompare(trimmedPeer) == .orderedSame }) {
            contacts[index].name = trimmedName
        } else {
            let colorIndex = contacts.count % avatarColors.count
            let newContact = Contact(
                name: trimmedName,
                peerId: trimmedPeer,
                avatarColorHex: avatarColors[colorIndex]
            )
            contacts.insert(newContact, at: 0)
        }

        saveContacts()

        // Update name in history
        for i in 0..<callHistory.count {
            if callHistory[i].peerId.caseInsensitiveCompare(trimmedPeer) == .orderedSame {
                callHistory[i].peerName = trimmedName
            }
        }
        saveHistory()
    }

    public func deleteContact(id: String) {
        contacts.removeAll { $0.id == id }
        saveContacts()
    }

    public func addCallRecord(peerId: String, direction: CallDirection, durationSeconds: Int) {
        let resolvedName = resolvePeerName(peerId: peerId)
        let record = CallHistoryItem(
            peerId: peerId,
            peerName: resolvedName,
            direction: direction,
            durationSeconds: durationSeconds
        )

        callHistory.insert(record, at: 0)
        if callHistory.count > 50 {
            callHistory = Array(callHistory.prefix(50))
        }
        saveHistory()
    }

    public func clearHistory() {
        callHistory.removeAll()
        try? fileManager.removeItem(at: historyFileURL)
    }

    public func resolvePeerName(peerId: String) -> String? {
        let trimmed = peerId.trimmingCharacters(in: .whitespacesAndNewlines)
        return contacts.first(where: { $0.peerId.caseInsensitiveCompare(trimmed) == .orderedSame })?.name
    }

    private func saveContacts() {
        if let data = try? JSONEncoder().encode(contacts) {
            try? data.write(to: contactsFileURL, options: .atomic)
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(callHistory) {
            try? data.write(to: historyFileURL, options: .atomic)
        }
    }
}
