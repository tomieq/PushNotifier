import Foundation

/// A push notification request sent to APNs for a single device.
///
/// Use the generic `Payload` parameter to send either the built-in
/// ``APNSPayload`` or a custom type conforming to ``APNSNotificationPayload``.
public struct APNSNotification<Payload: APNSNotificationPayload>: Sendable {
    /// The hex-encoded device token received from the device.
    public let deviceToken: String
    /// The notification payload to deliver.
    public let payload: Payload
    /// The push type. Defaults to `.alert`.
    public let pushType: APNSPushType
    /// The delivery priority. Defaults to `.immediately`.
    public let priority: APNSPriority
    /// The date after which the notification is no longer valid.
    /// If `nil`, APNs stores the notification for up to 30 days.
    public let expiration: Date?
    /// An identifier used to coalesce multiple notifications into one.
    public let collapseID: String?
    /// A canonical UUID that identifies the notification. APNs generates
    /// one automatically when `nil`.
    public let apnsID: UUID?

    public init(
        deviceToken: String,
        payload: Payload,
        pushType: APNSPushType = .alert,
        priority: APNSPriority = .immediately,
        expiration: Date? = nil,
        collapseID: String? = nil,
        apnsID: UUID? = nil
    ) {
        self.deviceToken = deviceToken
        self.payload = payload
        self.pushType = pushType
        self.priority = priority
        self.expiration = expiration
        self.collapseID = collapseID
        self.apnsID = apnsID
    }
}
