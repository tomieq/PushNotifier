/// Authentication credentials used to sign JWT tokens for APNs.
///
/// Obtain the key ID and team ID from the Apple Developer portal, and the
/// private key from the `.p8` file downloaded when you create an APNs key.
public struct APNSCredentials: Sendable {
    /// The 10-character key identifier from the Apple Developer portal.
    public let keyID: String
    /// The 10-character team identifier from the Apple Developer portal.
    public let teamID: String
    /// The PEM-encoded PKCS#8 private key from the `.p8` file.
    public let privateKeyPEM: String

    public init(keyID: String, teamID: String, privateKeyPEM: String) {
        self.keyID = keyID
        self.teamID = teamID
        self.privateKeyPEM = privateKeyPEM
    }
}
