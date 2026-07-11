/// The kind of notification to send.
///
/// Use `.background` for silent pushes that wake the app and `.userInterface`
/// for notifications that can alert the user, update badges, play sounds, or
/// attach a remote image through a Notification Service Extension.
public enum APNSNotificationContent: Sendable {
    case background(APNSBackgroundNotification)
    case userInterface(APNSUserNotification)
}