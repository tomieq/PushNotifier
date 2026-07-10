import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The main client for sending push notifications to Apple's APNs servers.
///
/// Create a single long-lived `APNSClient` instance and reuse it across your
/// application. The client handles JWT token generation and caching internally.
///
/// ## Example
/// ```swift
/// let credentials = APNSCredentials(
///     keyID: "KEYID12345",
///     teamID: "TEAM12345",
///     privateKeyPEM: "-----BEGIN PRIVATE KEY-----\n..."
/// )
/// let config = APNSConfiguration(
///     credentials: credentials,
///     topic: "com.example.MyApp",
///     environment: .sandbox
/// )
/// let client = APNSClient(configuration: config)
///
/// let alert   = APNSAlert(title: "Hello", body: "World")
/// let payload = APNSPayload(alert: alert, badge: 1, sound: .default)
/// let note    = APNSNotification(deviceToken: deviceToken, payload: payload)
///
/// try await client.send(note)
/// ```
public final class APNSClient: Sendable {

    private let configuration: APNSConfiguration
    private let session: URLSession
    private let jwtGenerator: JWTGenerator

    // MARK: - Initialisation

    public convenience init(configuration: APNSConfiguration) {
        let sessionConfig = URLSessionConfiguration.default
        self.init(configuration: configuration, session: URLSession(configuration: sessionConfig))
    }

    /// Initialises the client with a custom `URLSession`, useful for testing.
    init(configuration: APNSConfiguration, session: URLSession) {
        self.configuration = configuration
        self.session       = session
        self.jwtGenerator  = JWTGenerator(credentials: configuration.credentials)
    }

    // MARK: - Sending

    /// Sends a single push notification to APNs.
    ///
    /// - Parameter notification: The notification to send.
    /// - Throws: ``APNSError`` if the token cannot be signed, the request
    ///   fails at the network layer, or APNs rejects the notification.
    public func send<Payload: APNSNotificationPayload>(
        _ notification: APNSNotification<Payload>
    ) async throws {
        let token = try await jwtGenerator.token()
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(notification.payload)

        try validate(notification: notification, payloadData: payloadData)

        var request = try buildRequest(for: notification, bearerToken: token)
        request.httpBody = payloadData

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APNSError.networkError(UnknownNetworkError(message: error.localizedDescription))
        }

        guard let http = response as? HTTPURLResponse else {
            throw APNSError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let errorBody = try? JSONDecoder().decode(APNSErrorBody.self, from: data)
            let reason    = errorBody.flatMap { APNSRejectionReason(rawValue: $0.reason) }
            throw APNSError.rejected(statusCode: http.statusCode, reason: reason)
        }
    }

    // MARK: - Private helpers

    private func buildRequest<Payload: APNSNotificationPayload>(
        for notification: APNSNotification<Payload>,
        bearerToken: String
    ) throws -> URLRequest {
        let url = apnsURL(deviceToken: notification.deviceToken)
        var request        = URLRequest(url: url)
        request.httpMethod = "POST"

        request.setValue("application/json",             forHTTPHeaderField: "content-type")
        request.setValue("bearer \(bearerToken)",        forHTTPHeaderField: "authorization")
        request.setValue(configuration.topic,            forHTTPHeaderField: "apns-topic")
        request.setValue(notification.pushType.rawValue, forHTTPHeaderField: "apns-push-type")
        request.setValue(String(notification.priority.rawValue), forHTTPHeaderField: "apns-priority")

        if let expiration = notification.expiration {
            request.setValue(
                String(Int(expiration.timeIntervalSince1970)),
                forHTTPHeaderField: "apns-expiration"
            )
        }
        if let collapseID = notification.collapseID {
            request.setValue(collapseID, forHTTPHeaderField: "apns-collapse-id")
        }
        if let apnsID = notification.apnsID {
            request.setValue(apnsID.uuidString.lowercased(), forHTTPHeaderField: "apns-id")
        }

        return request
    }

    private func apnsURL(deviceToken: String) -> URL {
        var components    = URLComponents()
        components.scheme = "https"
        components.host   = configuration.environment.host
        components.port   = 443
        components.path   = "/3/device/\(deviceToken)"
        // URLComponents.url is nil only when the components are malformed;
        // ours are always valid, so the force-unwrap is safe.
        return components.url!
    }

    private func validate<Payload: APNSNotificationPayload>(
        notification: APNSNotification<Payload>,
        payloadData: Data
    ) throws {
        guard notification.pushType == .background else {
            return
        }

        guard notification.priority == .considerPower else {
            throw APNSError.invalidNotification(
                "Background notifications must use priority .considerPower (apns-priority: 5)."
            )
        }

        let payloadObject = try JSONSerialization.jsonObject(with: payloadData)
        let payload = payloadObject as? [String: Any]
        let aps = payload?["aps"] as? [String: Any]

        guard let contentAvailable = aps?["content-available"] as? NSNumber,
              contentAvailable.intValue == 1 else {
            throw APNSError.invalidNotification(
                "Background notifications must encode aps.content-available = 1."
            )
        }

        let hasAlert = aps?["alert"] != nil
        let hasSound = aps?["sound"] != nil
        let hasBadge = aps?["badge"] != nil

        guard !hasAlert && !hasSound && !hasBadge else {
            throw APNSError.invalidNotification(
                "Background notifications must not include alert, sound, or badge in aps. Use pushType .alert for user-visible notifications."
            )
        }
    }
}

// MARK: - APNs error response body

private struct APNSErrorBody: Decodable {
    let reason: String
    let timestamp: Int?
}

// MARK: - Wrapper for non-Sendable errors

private struct UnknownNetworkError: Error, Sendable {
    let message: String
}
