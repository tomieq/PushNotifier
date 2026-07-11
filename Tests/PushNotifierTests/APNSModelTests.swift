import Testing
import Foundation
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

// MARK: - APNSPayload encoding

@Suite("APNSPayload Encoding")
struct APNSPayloadTests {

    @Test("Wraps all fields inside the aps key")
    func wrapsInsideAPS() throws {
        let alert   = APNSAlert(title: "Hi", body: "There")
        let payload = APNSPayload(alert: alert, badge: 3, sound: .default)
        let data    = try JSONEncoder().encode(payload)
        let json    = try jsonObject(data)

        let aps = try #require(json["aps"] as? [String: Any])
        #expect((aps["alert"] as? [String: Any])?["title"] as? String == "Hi")
        #expect((aps["alert"] as? [String: Any])?["body"]  as? String == "There")
        #expect(aps["badge"]  as? Int    == 3)
        #expect(aps["sound"]  as? String == "default")
    }

    @Test("contentAvailable encodes as integer 1")
    func contentAvailableIsInt() throws {
        let payload = APNSPayload(contentAvailable: true)
        let data    = try JSONEncoder().encode(payload)
        let json    = try jsonObject(data)
        let aps     = try #require(json["aps"] as? [String: Any])
        #expect(aps["content-available"] as? Int == 1)
    }

    @Test("mutableContent encodes as integer 1")
    func mutableContentIsInt() throws {
        let payload = APNSPayload(mutableContent: true)
        let data    = try JSONEncoder().encode(payload)
        let json    = try jsonObject(data)
        let aps     = try #require(json["aps"] as? [String: Any])
        #expect(aps["mutable-content"] as? Int == 1)
    }

    @Test("Nil optional fields are omitted from JSON")
    func nilFieldsOmitted() throws {
        let payload = APNSPayload(alert: APNSAlert(title: "X"))
        let data    = try JSONEncoder().encode(payload)
        let json    = try jsonObject(data)
        let aps     = try #require(json["aps"] as? [String: Any])

        #expect(aps["badge"]             == nil)
        #expect(aps["sound"]             == nil)
        #expect(aps["content-available"] == nil)
        #expect(aps["mutable-content"]   == nil)
        #expect(aps["category"]          == nil)
        #expect(aps["thread-id"]         == nil)
    }

    @Test("threadID uses thread-id APNs key")
    func threadIDKey() throws {
        let payload = APNSPayload(threadID: "conversation-1")
        let data    = try JSONEncoder().encode(payload)
        let json    = try jsonObject(data)
        let aps     = try #require(json["aps"] as? [String: Any])
        #expect(aps["thread-id"] as? String == "conversation-1")
    }

    @Test("category field is encoded")
    func categoryEncoded() throws {
        let payload = APNSPayload(category: "REPLY_ACTION")
        let data    = try JSONEncoder().encode(payload)
        let json    = try jsonObject(data)
        let aps     = try #require(json["aps"] as? [String: Any])
        #expect(aps["category"] as? String == "REPLY_ACTION")
    }
}

// MARK: - APNSNotification defaults

@Suite("APNSNotification Defaults")
struct APNSNotificationTests {

    @Test("Default push type is alert")
    func defaultPushType() {
        let note = APNSNotification(deviceToken: "abc", payload: APNSPayload())
        #expect(note.pushType == .alert)
    }

    @Test("Default priority is immediately")
    func defaultPriority() {
        let note = APNSNotification(deviceToken: "abc", payload: APNSPayload())
        #expect(note.priority == .immediately)
    }

    @Test("Optional fields default to nil")
    func optionalFieldsNil() {
        let note = APNSNotification(deviceToken: "abc", payload: APNSPayload())
        #expect(note.expiration == nil)
        #expect(note.collapseID == nil)
        #expect(note.apnsID     == nil)
    }

    @Test("Custom values are preserved")
    func customValuesPreserved() {
        let expiry = Date(timeIntervalSinceNow: 3600)
        let id     = UUID()
        let note   = APNSNotification(
            deviceToken: "token123",
            payload: APNSPayload(),
            pushType: .background,
            priority: .considerPower,
            expiration: expiry,
            collapseID: "group-1",
            apnsID: id
        )
        #expect(note.deviceToken == "token123")
        #expect(note.pushType    == .background)
        #expect(note.priority    == .considerPower)
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

@Suite("Background Notification Validation")
struct BackgroundNotificationValidationTests {

    @Test("Background push requires content-available")
    func backgroundPushRequiresContentAvailable() async {
        let client = makeClient()

        struct Payload: APNSNotificationPayload {
            struct APS: Encodable {
                let badge: Int
            }

            let aps: APS
            let deepLink: String
        }

        let notification = APNSNotification(
            deviceToken: "abc123",
            payload: Payload(aps: .init(badge: 0), deepLink: "myapp://home"),
            pushType: .background,
            priority: .considerPower
        )

        do {
            try await client.send(notification)
            Issue.record("Expected invalid background notification error")
        } catch APNSError.invalidNotification(let message) {
            #expect(message == "Background notifications must encode aps.content-available = 1.")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Background push rejects alert payloads")
    func backgroundPushRejectsAlertPayloads() async {
        let client = makeClient()

        let payload = APNSPayload(
            alert: APNSAlert(title: "Welcome", body: "Tap to open"),
            badge: 0,
            contentAvailable: true
        )

        let notification = APNSNotification(
            deviceToken: "abc123",
            payload: payload,
            pushType: .background,
            priority: .considerPower
        )

        do {
            try await client.send(notification)
            Issue.record("Expected invalid background notification error")
        } catch APNSError.invalidNotification(let message) {
            #expect(message == "Background notifications must not include alert, sound, or badge in aps. Use pushType .alert for user-visible notifications.")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Background push requires priority 5")
    func backgroundPushRequiresPriorityFive() async {
        let client = makeClient()

        let payload = APNSPayload(contentAvailable: true)
        let notification = APNSNotification(
            deviceToken: "abc123",
            payload: payload,
            pushType: .background,
            priority: .immediately
        )

        do {
            try await client.send(notification)
            Issue.record("Expected invalid background notification error")
        } catch APNSError.invalidNotification(let message) {
            #expect(message == "Background notifications must use priority .considerPower (apns-priority: 5).")
        } catch {
            Issue.record("Unexpected error: \(error)")
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
