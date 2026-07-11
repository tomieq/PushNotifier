/// A silent background push that wakes the app and forwards custom top-level data.
public struct APNSBackgroundNotification: Sendable {
    public let customData: APNSCustomData

    public init() {
        self.customData = .empty
    }

    public init<CustomData: Encodable & Sendable>(customData: CustomData) {
        self.customData = APNSCustomData(customData)
    }
}