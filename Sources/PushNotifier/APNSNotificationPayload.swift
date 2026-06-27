/// A protocol that any APNs notification payload must conform to.
///
/// Conform your own type to this protocol when you need to include custom
/// keys in the notification JSON alongside the standard `aps` dictionary.
///
/// ```swift
/// struct MyPayload: APNSNotificationPayload {
///     struct APS: Encodable {
///         let alert: APNSAlert
///         let badge: Int
///     }
///     let aps: APS
///     let deepLink: String   // custom key sent alongside "aps"
/// }
/// ```
public protocol APNSNotificationPayload: Encodable, Sendable {}
