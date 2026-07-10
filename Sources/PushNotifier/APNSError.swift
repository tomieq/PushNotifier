import Foundation

/// Errors that can be thrown by ``APNSClient``.
public enum APNSError: Error, LocalizedError, Sendable {
    /// The PEM private key in ``APNSCredentials`` is invalid or cannot be parsed.
    case invalidPrivateKey(String)
    /// The notification configuration is invalid for the selected APNs push type.
    case invalidNotification(String)
    /// APNs returned a non-200 HTTP status code.
    case rejected(statusCode: Int, reason: APNSRejectionReason?)
    /// The HTTP response received was not an `HTTPURLResponse`.
    case invalidResponse
    /// An underlying network error occurred.
    case networkError(any Error & Sendable)

    public var errorDescription: String? {
        switch self {
        case .invalidPrivateKey(let detail):
            return "Invalid APNs private key: \(detail)"
        case .invalidNotification(let detail):
            return "Invalid APNs notification: \(detail)"
        case .rejected(let status, let reason):
            let reasonText = reason?.rawValue ?? "unknown"
            return "APNs rejected the notification (HTTP \(status), reason: \(reasonText))"
        case .invalidResponse:
            return "Received an invalid response from APNs"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

/// Typed rejection reasons returned in the APNs error response body.
public struct APNSRejectionReason: RawRepresentable, Sendable, Equatable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // Device / token errors
    public static let badDeviceToken          = APNSRejectionReason(rawValue: "BadDeviceToken")
    public static let unregistered            = APNSRejectionReason(rawValue: "Unregistered")
    public static let deviceTokenNotForTopic  = APNSRejectionReason(rawValue: "DeviceTokenNotForTopic")
    // Payload errors
    public static let payloadEmpty            = APNSRejectionReason(rawValue: "PayloadEmpty")
    public static let payloadTooLarge         = APNSRejectionReason(rawValue: "PayloadTooLarge")
    public static let invalidContentAvailable = APNSRejectionReason(rawValue: "InvalidContentAvailable")
    // Auth errors
    public static let badCertificate          = APNSRejectionReason(rawValue: "BadCertificate")
    public static let expiredProviderToken    = APNSRejectionReason(rawValue: "ExpiredProviderToken")
    public static let invalidProviderToken    = APNSRejectionReason(rawValue: "InvalidProviderToken")
    // Topic / configuration errors
    public static let badTopic                = APNSRejectionReason(rawValue: "BadTopic")
    public static let topicDisallowed         = APNSRejectionReason(rawValue: "TopicDisallowed")
    public static let missingTopic            = APNSRejectionReason(rawValue: "MissingTopic")
    // Other
    public static let tooManyRequests         = APNSRejectionReason(rawValue: "TooManyRequests")
    public static let serviceUnavailable      = APNSRejectionReason(rawValue: "ServiceUnavailable")
    public static let shutdown                = APNSRejectionReason(rawValue: "Shutdown")
}
