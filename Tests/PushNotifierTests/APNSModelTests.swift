import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PushNotifier

private let testPrivateKeyPEM = """
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg4Lfxvx8t94Kum1vM
Ar5fRzAzgPWv3K6v1o+BdY9a6nOhRANCAATjiKeg7XWmc1CRkH+ad+vdrNgPpBxh
wpk8+sXvB0GrVbKUPy7uUZMcyBj8KAZakmDO1W96T4vSz2VgZCUUWQK8
-----END PRIVATE KEY-----
"""

// MARK: - APNSAlert encoding

@Suite("APNSAlert Encoding")
struct APNSAlertTests {

    @Test("Encodes title only")
    func encodesTitle() throws {
        let alert = APNSAlert(title: "Hello")
        let data  = try JSONEncoder().encode(alert)
        let json  = try jsonObject(data)

        #expect(json["title"] as? String == "Hello")
        #expect(json["subtitle"] == nil)
        #expect(json["body"] == nil)
    }

    @Test("Encodes all standard fields")
    func encodesAllFields() throws {
        let alert = APNSAlert(title: "T", subtitle: "S", body: "B")
        let data  = try JSONEncoder().encode(alert)
        let json  = try jsonObject(data)

        #expect(json["title"]    as? String == "T")
        #expect(json["subtitle"] as? String == "S")
        #expect(json["body"]     as? String == "B")
    }

    @Test("Encodes localisation keys with APNs snake-case names")
    func encodesLocalisationKeys() throws {
        let alert = APNSAlert(
            title: "T",
            titleLocKey: "TITLE_KEY",
            titleLocArgs: ["arg1"],
            locKey: "BODY_KEY",
            locArgs: ["arg2"]
        )
        let data = try JSONEncoder().encode(alert)
        let json = try jsonObject(data)

        #expect(json["title-loc-key"]  as? String       == "TITLE_KEY")
        #expect(json["title-loc-args"] as? [String]     == ["arg1"])
        #expect(json["loc-key"]        as? String       == "BODY_KEY")
        #expect(json["loc-args"]       as? [String]     == ["arg2"])
    }
}

// MARK: - APNSSound encoding

@Suite("APNSSound Encoding")
struct APNSSoundTests {

    @Test("Default sound encodes to \"default\"")
    func encodesDefault() throws {
        let data = try JSONEncoder().encode(APNSSound.default)
        let str  = String(data: data, encoding: .utf8)
        #expect(str == "\"default\"")
    }

    @Test("Named sound encodes to its name")
    func encodesNamed() throws {
        let data = try JSONEncoder().encode(APNSSound.named("chime"))
        let str  = String(data: data, encoding: .utf8)
        #expect(str == "\"chime\"")
    }
}

// MARK: - APNSNotification payload encoding

@Suite("APNSNotification Payload Encoding")
struct APNSNotificationPayloadEncodingTests {

    @Test("Background notifications encode custom data with content-available")
    func backgroundPayloadEncoding() throws {
        let client = makeClient()

        struct CustomData: Encodable, Sendable {
            let deepLink: String
            let syncReason: String
        }

        let notification = APNSNotification(
            deviceToken: "abc123",
            content: .background(
                APNSBackgroundNotification(
                    customData: CustomData(
                        deepLink: "myapp://home",
                        syncReason: "wallet-updated"
                    )
                )
            )
        )

        let data = try client.payloadData(for: notification)
        let json = try jsonObject(data)
        let aps = try #require(json["aps"] as? [String: Any])

        #expect(aps["content-available"] as? Int == 1)
        #expect(json["deepLink"] as? String == "myapp://home")
        #expect(json["syncReason"] as? String == "wallet-updated")
    }

    @Test("User interface notifications encode aps fields")
    func userInterfacePayloadEncoding() throws {
        let client = makeClient()
        let notification = APNSNotification(
            deviceToken: "abc123",
            content: .userInterface(
                APNSUserNotification(
                    alert: APNSAlert(title: "Hi", body: "There"),
                    badge: 3,
                    sound: .default,
                    contentAvailable: true,
                    category: "REPLY_ACTION",
                    threadID: "conversation-1"
                )
            )
        )

        let data = try client.payloadData(for: notification)
        let json = try jsonObject(data)
        let aps = try #require(json["aps"] as? [String: Any])

        #expect((aps["alert"] as? [String: Any])?["title"] as? String == "Hi")
        #expect((aps["alert"] as? [String: Any])?["body"] as? String == "There")
        #expect(aps["badge"] as? Int == 3)
        #expect(aps["sound"] as? String == "default")
        #expect(aps["content-available"] as? Int == 1)
        #expect(aps["category"] as? String == "REPLY_ACTION")
        #expect(aps["thread-id"] as? String == "conversation-1")
    }

    @Test("Empty custom payload encodes as an empty object")
    func emptyPayloadEncoding() throws {
        let data = try JSONEncoder().encode(APNSEmptyPayload())
        let json = try jsonObject(data)
        #expect(json.isEmpty)
    }
}

// MARK: - APNSNotification defaults

@Suite("APNSNotification Defaults")
struct APNSNotificationTests {

    @Test("Optional fields default to nil")
    func optionalFieldsNil() {
        let note = APNSNotification(
            deviceToken: "abc",
            content: .background(APNSBackgroundNotification())
        )
        #expect(note.expiration == nil)
        #expect(note.collapseID == nil)
        #expect(note.apnsID     == nil)
    }

    @Test("Content and metadata values are preserved")
    func customValuesPreserved() {
        let expiry = Date(timeIntervalSinceNow: 3600)
        let id     = UUID()
        let note   = APNSNotification(
            deviceToken: "token123",
            content: .userInterface(
                APNSUserNotification(alert: APNSAlert(title: "Welcome"))
            ),
            expiration: expiry,
            collapseID: "group-1",
            apnsID: id
        )
        #expect(note.deviceToken == "token123")
        #expect(note.expiration  == expiry)
        #expect(note.collapseID  == "group-1")
        #expect(note.apnsID      == id)
    }
}

// MARK: - APNSRejectionReason

@Suite("APNSRejectionReason")
struct APNSRejectionReasonTests {

    @Test("Raw value round-trips")
    func rawValueRoundTrip() {
        let reason = APNSRejectionReason(rawValue: "BadDeviceToken")
        #expect(reason == .badDeviceToken)
    }

    @Test("Unknown reason preserves raw value")
    func unknownReason() {
        let reason = APNSRejectionReason(rawValue: "SomeFutureReason")
        #expect(reason.rawValue == "SomeFutureReason")
    }
}

// MARK: - Helpers

private func jsonObject(_ data: Data) throws -> [String: Any] {
    let obj = try JSONSerialization.jsonObject(with: data)
    return try #require(obj as? [String: Any])
}

// MARK: - Background notification validation

@Suite("Notification Request Validation")
struct NotificationRequestValidationTests {

    @Test("Background notifications derive background headers")
    func backgroundHeaders() {
        let notification = APNSNotification(
            deviceToken: "abc123",
            content: .background(APNSBackgroundNotification())
        )

        #expect(notification.pushType == .background)
        #expect(notification.priority == .considerPower)
    }

    @Test("User interface notifications derive alert headers")
    func userInterfaceHeaders() {
        let notification = APNSNotification(
            deviceToken: "abc123",
            content: .userInterface(
                APNSUserNotification(alert: APNSAlert(title: "Hello"), badge: 1)
            )
        )

        #expect(notification.pushType == .alert)
        #expect(notification.priority == .immediately)
    }

    @Test("Custom data must encode to a top-level object")
    func customDataMustBeJSONObject() throws {
        let client = makeClient()
        let notification = APNSNotification(
            deviceToken: "abc123",
            content: .background(APNSBackgroundNotification(customData: ["one", "two"]))
        )

        do {
            _ = try client.payloadData(for: notification)
            Issue.record("Expected invalid notification error")
        } catch APNSError.invalidNotification(let message) {
            #expect(message == "Custom data must encode to a top-level JSON object.")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Custom data must not override aps")
    func customDataMustNotOverrideAPS() throws {
        let client = makeClient()

        struct ConflictingData: Encodable, Sendable {
            let aps: String
        }

        let notification = APNSNotification(
            deviceToken: "abc123",
            content: .background(APNSBackgroundNotification(customData: ConflictingData(aps: "bad")))
        )

        do {
            _ = try client.payloadData(for: notification)
            Issue.record("Expected invalid notification error")
        } catch APNSError.invalidNotification(let message) {
            #expect(message == "Custom data must not encode the reserved top-level key \"aps\".")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private func makeClient() -> APNSClient {
    let credentials = APNSCredentials(
        keyID: "KEYID12345",
        teamID: "TEAM12345",
        privateKeyPEM: testPrivateKeyPEM
    )
    let configuration = APNSConfiguration(
        credentials: credentials,
        topic: "com.example.MyApp",
        environment: .sandbox
    )
    let sessionConfig = URLSessionConfiguration.ephemeral
    sessionConfig.protocolClasses = [UnexpectedNetworkURLProtocol.self]
    let session = URLSession(configuration: sessionConfig)
    return APNSClient(configuration: configuration, session: session)
}

private final class UnexpectedNetworkURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
    }

    override func stopLoading() {}
}
