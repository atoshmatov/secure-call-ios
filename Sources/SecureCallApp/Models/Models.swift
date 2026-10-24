import Foundation

public enum CallDirection: String, Codable {
    case incoming
    case outgoing
    case missed
}

public struct Contact: Identifiable, Codable, Equatable {
    public let id: String
    public var name: String
    public var peerId: String
    public var createdAt: Date
    public var avatarColorHex: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        peerId: String,
        createdAt: Date = Date(),
        avatarColorHex: String = "#3B82F6"
    ) {
        self.id = id
        self.name = name
        self.peerId = peerId
        self.createdAt = createdAt
        self.avatarColorHex = avatarColorHex
    }
}

public struct CallHistoryItem: Identifiable, Codable, Equatable {
    public let id: String
    public let peerId: String
    public var peerName: String?
    public let direction: CallDirection
    public let timestamp: Date
    public let durationSeconds: Int

    public init(
        id: String = UUID().uuidString,
        peerId: String,
        peerName: String? = nil,
        direction: CallDirection,
        timestamp: Date = Date(),
        durationSeconds: Int = 0
    ) {
        self.id = id
        self.peerId = peerId
        self.peerName = peerName
        self.direction = direction
        self.timestamp = timestamp
        self.durationSeconds = durationSeconds
    }
}
