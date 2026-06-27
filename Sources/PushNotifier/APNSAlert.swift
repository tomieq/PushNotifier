/// The visible alert portion of an APNs notification payload.
public struct APNSAlert: Encodable, Sendable {
    /// The title displayed prominently at the top of the notification.
    public let title: String
    /// An optional secondary title displayed below the main title.
    public let subtitle: String?
    /// The body text of the notification.
    public let body: String?
    /// A key referencing a localized title string in `Localizable.strings`.
    public let titleLocKey: String?
    /// Arguments to substitute into the localized title string.
    public let titleLocArgs: [String]?
    /// A key referencing a localized body string in `Localizable.strings`.
    public let locKey: String?
    /// Arguments to substitute into the localized body string.
    public let locArgs: [String]?

    public init(
        title: String,
        subtitle: String? = nil,
        body: String? = nil,
        titleLocKey: String? = nil,
        titleLocArgs: [String]? = nil,
        locKey: String? = nil,
        locArgs: [String]? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.titleLocKey = titleLocKey
        self.titleLocArgs = titleLocArgs
        self.locKey = locKey
        self.locArgs = locArgs
    }

    enum CodingKeys: String, CodingKey {
        case title, subtitle, body
        case titleLocKey  = "title-loc-key"
        case titleLocArgs = "title-loc-args"
        case locKey       = "loc-key"
        case locArgs      = "loc-args"
    }
}
