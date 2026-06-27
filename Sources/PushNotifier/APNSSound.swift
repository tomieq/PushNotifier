/// The sound played when a notification is delivered.
public enum APNSSound: Encodable, Sendable {
    /// The default system notification sound.
    case `default`
    /// A named sound file bundled with the app.
    case named(String)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .default:         try container.encode("default")
        case .named(let name): try container.encode(name)
        }
    }
}
