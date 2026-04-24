
import Foundation
import SwiftData

@Model
final class PlaylistSettingsItem {

    var order: String?
    var views: [String: Int] = [:] // Key is HMAC(title)
    var recent: [String: Date] = [:] // Key is HMAC(title)
    var encrypted: [String: String] = [:] // Key is HMAC(title), Value is AES-GCM

    init(order: String?) {
        self.order = order
    }
}

extension PlaylistSettingsItem: Codable {

    enum CodingKeys: String, CodingKey {
        case order
        case views
        case recent
        case encrypted
    }

    convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let order = try container.decodeIfPresent(String.self, forKey: .order)
        self.init(order: order)
        self.views = try container.decodeIfPresent([String: Int].self, forKey: .views) ?? [:]
        self.recent = try container.decodeIfPresent([String: Date].self, forKey: .recent) ?? [:]
        self.encrypted = try container.decodeIfPresent([String: String].self, forKey: .encrypted) ?? [:]
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(order, forKey: .order)
        try container.encode(views, forKey: .views)
        try container.encode(recent, forKey: .recent)
        try container.encode(encrypted, forKey: .encrypted)
    }
}

extension PlaylistSettingsItem {

    @Transient var orderType: StreamListOrder {
        get {
            guard let order = order else { return .none }
            return StreamListOrder(rawValue: order) ?? .none
        }
        set {
            order = newValue.rawValue
        }
    }

    enum StreamListOrder: String, Hashable, CaseIterable {
        case none
        case ascending
        case descending
        case mostViewed
        case recentViewed

        var title: String {
            switch self {
            case .none: return String(localized: "Default")
            case .ascending: return String(localized: "Alphabetical")
            case .descending: return String(localized: "Reverse Alphabetical")
            case .mostViewed: return String(localized: "Most Viewed")
            case .recentViewed: return String(localized: "Recently Viewed")
            }
        }
    }
}