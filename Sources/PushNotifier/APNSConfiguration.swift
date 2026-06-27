/// Configuration required to create an ``APNSClient``.
public struct APNSConfiguration: Sendable {
    /// The JWT signing credentials.
    public let credentials: APNSCredentials
    /// The bundle identifier of the app receiving notifications (`apns-topic`).
    public let topic: String
    /// The APNs environment to target. Defaults to `.production`.
    public let environment: APNSEnvironment

    public init(
        credentials: APNSCredentials,
        topic: String,
        environment: APNSEnvironment = .production
    ) {
        self.credentials = credentials
        self.topic = topic
        self.environment = environment
    }
}
