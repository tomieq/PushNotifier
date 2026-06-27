/// The push notification type sent to APNs via the `apns-push-type` header.
public enum APNSPushType: String, Sendable {
    /// A notification that displays an alert, plays a sound, or badges the app icon.
    case alert
    /// A silent notification that wakes the app in the background.
    case background
    /// A VoIP notification.
    case voip
    /// A notification for a watchOS complication.
    case complication
    /// A notification used by the file provider extension.
    case fileprovider
    /// A mobile device management notification.
    case mdm
    /// A Live Activity notification.
    case liveActivity = "liveactivity"
    /// A Push to Talk notification.
    case pushToTalk = "pushtotalk"
}
