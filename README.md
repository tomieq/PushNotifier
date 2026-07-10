# PushNotifier

A pure Swift library for sending Apple Push Notifications (APNs) directly via the Apple HTTP/2 API. No Firebase. Works on macOS and Linux.

## Requirements

- Swift 6.1+
- macOS 13+ / Linux

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/PushNotifier.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["PushNotifier"]
    ),
]
```

## Setup

### 1. Obtain APNs credentials

In the [Apple Developer portal](https://developer.apple.com/account/):

1. Go to **Certificates, Identifiers & Profiles → Keys**.
2. Create a new key with the **Apple Push Notifications service (APNs)** capability.
3. Download the `.p8` file — you can only download it once.
4. Note the **Key ID** and your **Team ID** (shown in the top-right corner of the portal).

### 2. Create a client

```swift
import PushNotifier

let pem = try String(contentsOf: URL(fileURLWithPath: "/path/to/AuthKey_KEYID.p8"))

let credentials = APNSCredentials(
    keyID:         "KEYID12345",   // 10-character key identifier
    teamID:        "TEAM12345",    // 10-character team identifier
    privateKeyPEM: pem             // full contents of the .p8 file
)

let configuration = APNSConfiguration(
    credentials: credentials,
    topic:       "com.example.MyApp",  // your app's bundle identifier
    environment: .sandbox              // use .production for live apps
)

let client = APNSClient(configuration: configuration)
```

`APNSClient` is `Sendable` and safe to share across async contexts. Create one instance and reuse it for the lifetime of your application.

## Sending a notification

### Simple alert

```swift
let alert   = APNSAlert(title: "New message", body: "You have a new message.")
let payload = APNSPayload(alert: alert, badge: 1, sound: .default)

let notification = APNSNotification(
    deviceToken: "a4b8c2d1...",  // hex device token from the device
    payload:     payload
)

try await client.send(notification)
```

### Background (silent) notification

```swift
let payload = APNSPayload(contentAvailable: true)

let notification = APNSNotification(
    deviceToken: deviceToken,
    payload:     payload,
    pushType:    .background,
    priority:    .considerPower
)

try await client.send(notification)
```

For a silent push with custom data, keep `aps` limited to `content-available: 1` and put your app data at the top level:

```swift
struct SyncPayload: APNSNotificationPayload {
    struct APS: Encodable {
        let contentAvailable = 1

        enum CodingKeys: String, CodingKey {
            case contentAvailable = "content-available"
        }
    }

    let aps = APS()
    let deepLink: String
    let syncReason: String
}

let payload = SyncPayload(
    deepLink: "myapp://home",
    syncReason: "wallet-updated"
)

let notification = APNSNotification(
    deviceToken: deviceToken,
    payload: payload,
    pushType: .background,
    priority: .considerPower
)

try await client.send(notification)
```

Silent pushes are subject to Apple delivery heuristics. On the app side, enable the `Remote notifications` background mode and implement `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`. Do not include `alert`, `sound`, or `badge` when using `pushType: .background`; if you need a visible notification, use `pushType: .alert` instead.

### Notification with collapse ID and expiry

```swift
let payload = APNSPayload(alert: APNSAlert(title: "Score update", body: "Team A 3 – 1 Team B"))

let notification = APNSNotification(
    deviceToken: deviceToken,
    payload:     payload,
    expiration:  Date(timeIntervalSinceNow: 3600),  // discard after 1 hour
    collapseID:  "score-update"                     // replaces earlier notification with the same ID
)

try await client.send(notification)
```

### Localised alert

```swift
let alert = APNSAlert(
    title:         "New message",
    titleLocKey:   "NOTIFICATION_TITLE",
    locKey:        "NOTIFICATION_BODY_%@",
    locArgs:       ["Alice"]
)

let notification = APNSNotification(
    deviceToken: deviceToken,
    payload:     APNSPayload(alert: alert, sound: .named("chime"))
)

try await client.send(notification)
```

### Custom payload

For notifications that need extra keys alongside `aps`, conform your own type to `APNSNotificationPayload`:

```swift
struct MyPayload: APNSNotificationPayload {
    struct Alert: Encodable {
        let title: String
        let body: String
    }
    struct APS: Encodable {
        let alert: Alert
        let badge: Int
    }
    let aps:      APS
    let deepLink: String  // custom top-level key
}

let payload = MyPayload(
    aps:      .init(alert: .init(title: "Welcome", body: "Tap to open"), badge: 0),
    deepLink: "myapp://home"
)

let notification = APNSNotification(deviceToken: deviceToken, payload: payload)
try await client.send(notification)
```

## Error handling

```swift
do {
    try await client.send(notification)
} catch APNSError.rejected(let statusCode, let reason) {
    if reason == .unregistered {
        // Device token is no longer valid — remove it from your database.
    } else {
        print("APNs rejected with HTTP \(statusCode): \(reason?.rawValue ?? "unknown")")
    }
} catch APNSError.invalidPrivateKey(let detail) {
    print("Invalid .p8 key: \(detail)")
} catch APNSError.networkError(let underlying) {
    print("Network error: \(underlying)")
}
```

### Rejection reasons

| Constant | APNs reason string | Description |
|---|---|---|
| `.badDeviceToken` | `BadDeviceToken` | The device token is invalid. |
| `.unregistered` | `Unregistered` | The device token is no longer active. |
| `.deviceTokenNotForTopic` | `DeviceTokenNotForTopic` | Token does not match the topic. |
| `.payloadTooLarge` | `PayloadTooLarge` | Payload exceeds 4 KB. |
| `.expiredProviderToken` | `ExpiredProviderToken` | JWT token has expired (handled automatically). |
| `.tooManyRequests` | `TooManyRequests` | Rate limit exceeded. |

All known reasons are declared as static constants on `APNSRejectionReason`. Unknown reasons from future APNs updates are preserved as-is via the `rawValue`.

## Authentication

The library uses **JWT token-based authentication** (`.p8` key). Tokens are signed with ES256, cached, and automatically refreshed 5 minutes before the 1-hour APNs validity window closes.

Certificate-based authentication (`.p12`) is not supported.

## API reference

### `APNSCredentials`
| Parameter | Type | Description |
|---|---|---|
| `keyID` | `String` | 10-character key identifier from the Developer portal. |
| `teamID` | `String` | 10-character team identifier from the Developer portal. |
| `privateKeyPEM` | `String` | Full contents of the `.p8` file. |

### `APNSConfiguration`
| Parameter | Type | Description |
|---|---|---|
| `credentials` | `APNSCredentials` | JWT signing credentials. |
| `topic` | `String` | App bundle identifier sent as `apns-topic`. |
| `environment` | `APNSEnvironment` | `.sandbox` or `.production`. Default: `.production`. |

### `APNSPayload`
| Parameter | Type | Description |
|---|---|---|
| `alert` | `APNSAlert?` | The visible alert. |
| `badge` | `Int?` | Badge count. Pass `0` to clear. |
| `sound` | `APNSSound?` | `.default` or `.named("filename")`. |
| `contentAvailable` | `Bool?` | `true` for silent background notifications. |
| `mutableContent` | `Bool?` | `true` to allow a Notification Service Extension to modify the payload. |
| `category` | `String?` | Action category identifier. |
| `threadID` | `String?` | Thread identifier for grouping notifications. |

### `APNSNotification`
| Parameter | Type | Description |
|---|---|---|
| `deviceToken` | `String` | Hex-encoded device token. |
| `payload` | `Payload` | Any type conforming to `APNSNotificationPayload`. |
| `pushType` | `APNSPushType` | `.alert`, `.background`, `.voip`, etc. Default: `.alert`. |
| `priority` | `APNSPriority` | `.immediately` (10) or `.considerPower` (5). Default: `.immediately`. |
| `expiration` | `Date?` | Discard date. `nil` keeps the notification for up to 30 days. |
| `collapseID` | `String?` | Coalescing key to replace earlier notifications. |
| `apnsID` | `UUID?` | Canonical notification identifier. APNs generates one if `nil`. |
