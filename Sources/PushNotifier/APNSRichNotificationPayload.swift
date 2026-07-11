import Foundation

/// A convenience payload for rich notifications that display a remote image.
///
/// Apple Push Notification service does not define a built-in `aps` field for
/// attachments. Rich notifications are typically implemented by sending a
/// visible alert with `mutable-content: 1` plus a custom top-level key
/// containing the remote image URL. Your app's Notification Service Extension
/// then downloads that image and attaches it before presentation.
public struct APNSRichNotificationPayload: APNSNotificationPayload {
    /// The standard `aps` payload sent to APNs.
    public let aps: APNSPayload
    /// The remote image URL that your Notification Service Extension should download.
    public let imageURL: URL
    /// The top-level payload key used to encode `imageURL`.
    public let imageURLKey: String

    public init(
        alert: APNSAlert,
        badge: Int? = nil,
        sound: APNSSound? = nil,
        category: String? = nil,
        threadID: String? = nil,
        contentAvailable: Bool? = nil,
        imageURL: URL,
        imageURLKey: String = "image-url"
    ) {
        self.aps = APNSPayload(
            alert: alert,
            badge: badge,
            sound: sound,
            contentAvailable: contentAvailable,
            mutableContent: true,
            category: category,
            threadID: threadID
        )
        self.imageURL = imageURL
        self.imageURLKey = imageURLKey
    }

    private enum CodingKeys: String, CodingKey {
        case aps
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(aps.makeAPS(), forKey: .aps)

        var dynamicContainer = encoder.container(keyedBy: DynamicCodingKey.self)
        try dynamicContainer.encode(imageURL.absoluteString, forKey: DynamicCodingKey(imageURLKey))
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        return nil
    }
}