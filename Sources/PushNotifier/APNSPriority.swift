/// The delivery priority of a push notification.
public enum APNSPriority: Int, Sendable {
    /// Send the notification immediately. Required for notifications with alerts,
    /// sounds, or badges. Corresponds to `apns-priority: 10`.
    case immediately = 10
    /// Send the notification at a time that conserves device power.
    /// Use for background notifications. Corresponds to `apns-priority: 5`.
    case considerPower = 5
}
