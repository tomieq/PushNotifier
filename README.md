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

Choose the notification content you want to send:

- `.background(...)` for silent pushes that wake the app and forward custom JSON to the device.
- `.userInterface(...)` for visible notifications with alerts, badges, sounds, categories, thread IDs, and optional remote images.

The library always creates the `aps` dictionary for you. Custom data is encoded only as top-level keys next to `aps`.

### User-visible notification

```swift
let notification = APNSNotification(
    deviceToken: "a4b8c2d1...",  // hex device token from the device
    content: .userInterface(
        APNSUserNotification(
            alert: APNSAlert(title: "New message", body: "You have a new message."),
            badge: 1,
            sound: .default
        )
    )
)

try await client.send(notification)
```

### Background (silent) notification

```swift
struct SyncData: Encodable, Sendable {
    let deepLink: String
    let syncReason: String
}

let notification = APNSNotification(
    deviceToken: deviceToken,
    content: .background(
        APNSBackgroundNotification(
            customData: SyncData(
                deepLink: "myapp://home",
                syncReason: "wallet-updated"
            )
        )
    )
)

try await client.send(notification)
```

Background notifications always send `aps.content-available = 1` and use APNs priority `5`. Silent pushes are still subject to Apple delivery heuristics. On the app side, enable the `Remote notifications` background mode and implement `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`.

### Notification with collapse ID and expiry

```swift
let notification = APNSNotification(
    deviceToken: deviceToken,
    content: .userInterface(
        APNSUserNotification(
            alert: APNSAlert(title: "Score update", body: "Team A 3 – 1 Team B")
        )
    ),
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
    content: .userInterface(
        APNSUserNotification(
            alert: alert,
            sound: .named("chime")
        )
    )
)

try await client.send(notification)
```

### User-visible notification with custom top-level data

For notifications that need extra keys alongside `aps`, pass an `Encodable` value as `customData`:

```swift
struct NotificationData: Encodable, Sendable {
    let deepLink: String
    let conversationID: String
}

let notification = APNSNotification(
    deviceToken: deviceToken,
    content: .userInterface(
        APNSUserNotification(
            alert: APNSAlert(title: "Welcome", body: "Tap to open"),
            badge: 0,
            customData: NotificationData(
                deepLink: "myapp://home",
                conversationID: "conversation-123"
            )
        )
    )
)

try await client.send(notification)
```

### Rich notification with an image

APNs does not have a standard `aps.image` field. Image notifications on iPhone are implemented as a visible alert with `mutable-content: 1` plus a custom top-level URL field that your app's `UNNotificationServiceExtension` downloads and attaches before display.

`PushNotifier` handles that pattern through `APNSUserNotification`:

```swift
struct ImageData: Codable {
    let imagePath: String
    enum CodingKeys: String, CodingKey {
        case imageUrl = "image-url"
    }
}
let notification = APNSNotification(
        deviceToken: deviceToken,
    content: .userInterface(
        APNSUserNotification(
            alert: APNSAlert(
                title: "New photo",
                body: "Alice sent a picture"
            ),
            sound: .default,
            mutableContent: true,
            customData: ImageData(imageUrl: "https://cdn.example.com/attachments/photo.jpg"))!
        )
    )
)

try await client.send(notification)
```

That encodes the payload as:

```json
{
    "aps": {
        "alert": {
            "title": "New photo",
            "body": "Alice sent a picture"
        },
        "sound": "default",
        "mutable-content": 1
    },
    "image-url": "https://cdn.example.com/attachments/photo.jpg"
}
```

If your Notification Service Extension expects a different top-level key, set `imageURLKey`:

```swift
let notification = APNSNotification(
    deviceToken: deviceToken,
    content: .userInterface(
        APNSUserNotification(
            alert: APNSAlert(title: "New photo"),
            imageURL: imageURL,
            imageURLKey: "media-url"
        )
    )
)
```

Your app must still implement a `UNNotificationServiceExtension`; APNs only transports the URL and does not download or render the image by itself.

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

### `APNSNotificationContent`
| Parameter | Type | Description |
|---|---|---|
| `.background(APNSBackgroundNotification)` | Case | Silent push that wakes the app and forwards custom top-level JSON. |
| `.userInterface(APNSUserNotification)` | Case | Visible notification with alert, badge, sound, category, thread ID, custom data, and optional image URL. |

### `APNSBackgroundNotification`
| Parameter | Type | Description |
|---|---|---|
| `customData` | Any `Encodable & Sendable` object | Custom top-level JSON forwarded to the app alongside `aps.content-available = 1`. |

### `APNSUserNotification`
| Parameter | Type | Description |
|---|---|---|
| `alert` | `APNSAlert?` | The visible alert. |
| `badge` | `Int?` | Badge count. Pass `0` to clear. |
| `sound` | `APNSSound?` | `.default` or `.named("filename")`. |
| `contentAvailable` | `Bool?` | Optional background wake-up flag to combine with the visible notification. |
| `mutableContent` | `Bool` | Set `true` to allow a Notification Service Extension to modify the payload. Automatically enabled when `imageURL` is set. |
| `category` | `String?` | Action category identifier. |
| `threadID` | `String?` | Thread identifier for grouping notifications. |
| `imageURL` | `URL?` | Remote image URL for your Notification Service Extension to download. |
| `imageURLKey` | `String` | Top-level payload key used to encode the image URL. Default: `"image-url"`. |
| `customData` | Any `Encodable & Sendable` object | Custom top-level JSON encoded alongside `aps`. |

### `APNSEmptyPayload`
| Parameter | Type | Description |
|---|---|---|
| none | n/a | Default custom payload type when no top-level custom fields are needed. |

### `APNSNotification`
| Parameter | Type | Description |
|---|---|---|
| `deviceToken` | `String` | Hex-encoded device token. |
| `content` | `APNSNotificationContent` | Choose `.background(...)` or `.userInterface(...)`. |
| `expiration` | `Date?` | Discard date. `nil` keeps the notification for up to 30 days. |
| `collapseID` | `String?` | Coalescing key to replace earlier notifications. |
| `apnsID` | `UUID?` | Canonical notification identifier. APNs generates one if `nil`. |
