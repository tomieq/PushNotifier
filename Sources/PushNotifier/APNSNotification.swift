import Foundation

/// A push notification request sent to APNs for a single device.
///
/// Any custom JSON is provided through the chosen ``APNSNotificationContent``.
public struct APNSNotification: Sendable {
    /// The hex-encoded device token received from the device.
    public let deviceToken: String
    /// The type of notification to send.
    public let content: APNSNotificationContent
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
        content: APNSNotificationContent,
        expiration: Date? = nil,
        collapseID: String? = nil,
        apnsID: UUID? = nil
    ) {
        self.deviceToken = deviceToken
        self.content = content
        self.expiration = expiration
        self.collapseID = collapseID
        self.apnsID = apnsID
    }
}

extension APNSNotification {
    var pushType: APNSPushType {
        switch content {
        case .background:
            .background
        case .userInterface:
            .alert
        }
    }

    var priority: APNSPriority {
        switch content {
        case .background:
            .considerPower
        case .userInterface:
            .immediately
        }
    }

    var customData: APNSCustomData {
        switch content {
        case .background(let backgroundNotification):
            backgroundNotification.customData
        case .userInterface(let userNotification):
            userNotification.customData
        }
    }
}
