import Foundation

/// A ready-made notification payload covering the standard APNs `aps` fields.
///
/// For notifications that need custom top-level keys alongside `aps`, define
/// your own type conforming to ``APNSNotificationPayload``.
public struct APNSPayload: APNSNotificationPayload {
    /// The visible alert shown to the user.
    public let alert: APNSAlert?
    /// The number to display as the app's badge. Pass `0` to clear the badge.
    public let badge: Int?
    /// The sound to play when the notification is delivered.
    public let sound: APNSSound?
    /// Set to `true` to wake the app in the background (silent notification).
    public let contentAvailable: Bool?
    /// Set to `true` to allow the Notification Service Extension to modify the payload.
    public let mutableContent: Bool?
    /// The category identifier for interactive notifications.
    public let category: String?
    /// A thread identifier to group related notifications.
    public let threadID: String?

    public init(
        alert: APNSAlert? = nil,
        badge: Int? = nil,
        sound: APNSSound? = nil,
        contentAvailable: Bool? = nil,
        mutableContent: Bool? = nil,
        category: String? = nil,
        threadID: String? = nil
    ) {
        self.alert = alert
        self.badge = badge
        self.sound = sound
        self.contentAvailable = contentAvailable
        self.mutableContent = mutableContent
        self.category = category
        self.threadID = threadID
    }

    // MARK: - Encodable

    private enum TopLevelKeys: String, CodingKey {
        case aps
    }

    struct APS: Encodable {
        let alert: APNSAlert?
        let badge: Int?
        let sound: APNSSound?
        let contentAvailable: Int?
        let mutableContent: Int?
        let category: String?
        let threadID: String?

        enum CodingKeys: String, CodingKey {
            case alert, badge, sound, category
            case contentAvailable = "content-available"
            case mutableContent   = "mutable-content"
            case threadID         = "thread-id"
        }
    }

    func makeAPS() -> APS {
        APS(
            alert: alert,
            badge: badge,
            sound: sound,
            contentAvailable: contentAvailable == true ? 1 : nil,
            mutableContent: mutableContent == true ? 1 : nil,
            category: category,
            threadID: threadID
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TopLevelKeys.self)
        try container.encode(makeAPS(), forKey: .aps)
    }
}
