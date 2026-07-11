import Foundation

/// A user-visible push notification.
///
/// This payload type covers alerts, badges, sounds, categories, thread IDs,
/// custom top-level data, and rich notifications that include a remote image
/// URL for a Notification Service Extension to download.
public struct APNSUserNotification: Sendable {
    public let alert: APNSAlert?
    public let badge: Int?
    public let sound: APNSSound?
    public let contentAvailable: Bool?
    public let mutableContent: Bool
    public let category: String?
    public let threadID: String?
    public let imageURL: URL?
    public let imageURLKey: String
    public let customData: APNSCustomData

    public init(
        alert: APNSAlert? = nil,
        badge: Int? = nil,
        sound: APNSSound? = nil,
        contentAvailable: Bool? = nil,
        mutableContent: Bool = false,
        category: String? = nil,
        threadID: String? = nil,
        imageURL: URL? = nil,
        imageURLKey: String = "image-url"
    ) {
        self.init(
            alert: alert,
            badge: badge,
            sound: sound,
            contentAvailable: contentAvailable,
            mutableContent: mutableContent,
            category: category,
            threadID: threadID,
            imageURL: imageURL,
            imageURLKey: imageURLKey,
            customData: APNSCustomData.empty
        )
    }

    public init<CustomData: Encodable & Sendable>(
        alert: APNSAlert? = nil,
        badge: Int? = nil,
        sound: APNSSound? = nil,
        contentAvailable: Bool? = nil,
        mutableContent: Bool = false,
        category: String? = nil,
        threadID: String? = nil,
        imageURL: URL? = nil,
        imageURLKey: String = "image-url",
        customData: CustomData
    ) {
        self.alert = alert
        self.badge = badge
        self.sound = sound
        self.contentAvailable = contentAvailable
        self.mutableContent = mutableContent
        self.category = category
        self.threadID = threadID
        self.imageURL = imageURL
        self.imageURLKey = imageURLKey
        self.customData = APNSCustomData(customData)
    }
}