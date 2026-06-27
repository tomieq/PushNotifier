import Testing
import Foundation
@preconcurrency import Crypto
@testable import PushNotifier

@Suite("JWTGenerator")
struct JWTGeneratorTests {

    // Store the PEM string (String is Sendable) to avoid concurrency issues with
    // P256.Signing.PrivateKey not being Sendable in swift-crypto on Linux.
    private static let testPrivateKeyPEM: String = P256.Signing.PrivateKey().pemRepresentation

    private func makeGenerator() -> JWTGenerator {
        let credentials = APNSCredentials(keyID: "KEYID12345", teamID: "TEAM12345", privateKeyPEM: Self.testPrivateKeyPEM)
        return JWTGenerator(credentials: credentials)
    }

    @Test("Generated token has three dot-separated parts")
    func tokenHasThreeParts() async throws {
        let generator = makeGenerator()
        let token     = try await generator.token()
        let parts     = token.split(separator: ".", omittingEmptySubsequences: false)
        #expect(parts.count == 3)
    }

    @Test("Header decodes to correct algorithm and key ID")
    func headerContentsAreCorrect() async throws {
        let generator = makeGenerator()
        let token     = try await generator.token()
        let header    = try decodeJWTPart(String(token.split(separator: ".")[0]))

        #expect(header["alg"] as? String == "ES256")
        #expect(header["kid"] as? String == "KEYID12345")
    }

    @Test("Claims contain issuer and issued-at timestamp")
    func claimsContainIssuerAndTimestamp() async throws {
        let before    = Int(Date().timeIntervalSince1970)
        let generator = makeGenerator()
        let token     = try await generator.token()
        let after     = Int(Date().timeIntervalSince1970)

        let claims = try decodeJWTPart(String(token.split(separator: ".")[1]))

        #expect(claims["iss"] as? String == "TEAM12345")
        let iat = try #require(claims["iat"] as? Int)
        #expect(iat >= before && iat <= after)
    }

    @Test("Cached token is returned on subsequent calls")
    func tokenIsCached() async throws {
        let generator = makeGenerator()
        let token1    = try await generator.token()
        let token2    = try await generator.token()
        #expect(token1 == token2)
    }

    @Test("Signature can be verified with the corresponding public key")
    func signatureIsValid() async throws {
        let generator  = makeGenerator()
        let token      = try await generator.token()
        let parts      = token.split(separator: ".")

        let signingInput = "\(parts[0]).\(parts[1])"
        let signature    = try P256.Signing.ECDSASignature(rawRepresentation: base64URLDecode(String(parts[2])))
        let privateKey   = try P256.Signing.PrivateKey(pemRepresentation: Self.testPrivateKeyPEM)
        let publicKey    = privateKey.publicKey

        let isValid = publicKey.isValidSignature(signature, for: Data(signingInput.utf8))
        #expect(isValid)
    }

    @Test("Invalid PEM throws an error")
    func invalidPEMThrows() async {
        let credentials = APNSCredentials(keyID: "K", teamID: "T", privateKeyPEM: "not-a-valid-key")
        let generator   = JWTGenerator(credentials: credentials)
        await #expect(throws: (any Error).self) {
            _ = try await generator.token()
        }
    }

    // MARK: - Helpers

    private func decodeJWTPart(_ encoded: String) throws -> [String: Any] {
        let data = try base64URLDecode(encoded)
        let obj  = try JSONSerialization.jsonObject(with: data)
        return try #require(obj as? [String: Any])
    }

    private func base64URLDecode(_ value: String) throws -> Data {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad to a multiple of 4.
        let remainder = base64.count % 4
        if remainder != 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid base64url"))
        }
        return data
    }
}
