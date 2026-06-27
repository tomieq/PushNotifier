import Foundation
import Crypto

/// Generates and caches ES256-signed JWT tokens for APNs provider authentication.
///
/// Tokens are valid for 1 hour. This generator caches the token and transparently
/// refreshes it 5 minutes before expiry to avoid rejected requests.
final class JWTGenerator: Sendable {

    private let credentials: APNSCredentials
    private let tokenCache = TokenCache()

    init(credentials: APNSCredentials) {
        self.credentials = credentials
    }

    /// Returns a valid JWT bearer token, generating a new one when needed.
    func token() async throws -> String {
        if let cached = await tokenCache.token() {
            return cached
        }
        let (newToken, expiry) = try makeToken()
        await tokenCache.store(token: newToken, expiry: expiry)
        return newToken
    }

    // MARK: - Private

    private func makeToken() throws -> (token: String, expiry: Date) {
        let now = Date()
        let issuedAt = Int(now.timeIntervalSince1970)

        let header  = JWTHeader(alg: "ES256", kid: credentials.keyID)
        let payload = JWTClaims(iss: credentials.teamID, iat: issuedAt)

        let encoder = JSONEncoder()
        // Sort keys for deterministic output.
        encoder.outputFormatting = .sortedKeys

        let headerEncoded  = try base64URLEncode(encoder.encode(header))
        let payloadEncoded = try base64URLEncode(encoder.encode(payload))
        let signingInput   = "\(headerEncoded).\(payloadEncoded)"

        let privateKey = try P256.Signing.PrivateKey(pemRepresentation: credentials.privateKeyPEM)
        let signature  = try privateKey.signature(for: Data(signingInput.utf8))

        let token  = "\(signingInput).\(base64URLEncode(signature.rawRepresentation))"
        // Refresh 5 minutes before the 1-hour APNs validity window closes.
        let expiry = now.addingTimeInterval(55 * 60)
        return (token, expiry)
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Token cache (actor for safe concurrent access)

private actor TokenCache {
    private var cachedToken: String?
    private var expiry: Date?

    func token() -> String? {
        guard let cachedToken, let expiry, Date() < expiry else { return nil }
        return cachedToken
    }

    func store(token: String, expiry: Date) {
        self.cachedToken = token
        self.expiry = expiry
    }
}

// MARK: - JWT structures

private struct JWTHeader: Encodable {
    let alg: String
    let kid: String
}

private struct JWTClaims: Encodable {
    let iss: String
    let iat: Int
}
