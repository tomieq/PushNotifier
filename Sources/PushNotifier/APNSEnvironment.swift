/// The APNs server environment to target.
public enum APNSEnvironment: Sendable {
    /// The sandbox environment used for development and testing.
    case sandbox
    /// The production environment for live apps.
    case production

    var host: String {
        switch self {
        case .sandbox:    return "api.sandbox.push.apple.com"
        case .production: return "api.push.apple.com"
        }
    }
}
