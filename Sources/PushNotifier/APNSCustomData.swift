/// Type-erased top-level custom JSON sent alongside `aps`.
public struct APNSCustomData: Encodable, Sendable {
    private let encodeValue: @Sendable (Encoder) throws -> Void

    public init<CustomData: Encodable & Sendable>(_ customData: CustomData) {
        self.encodeValue = { encoder in
            try customData.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

public extension APNSCustomData {
    static let empty = APNSCustomData(APNSEmptyPayload())
}