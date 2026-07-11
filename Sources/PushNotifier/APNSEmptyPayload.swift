/// An empty top-level custom payload.
///
/// Use this when a notification does not need any custom keys alongside `aps`.
public struct APNSEmptyPayload: Encodable, Sendable {
    public init() {}

    public func encode(to encoder: Encoder) throws {
        let container = encoder.container(keyedBy: CodingKeys.self)
        _ = container
    }

    private enum CodingKeys: CodingKey {}
}