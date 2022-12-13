//
//  Bundle2090000ru.swift
//  Channels
//
//  Created by Mikhail Demidov on 27.11.2020.
//

import Foundation

public enum Bundle2090000ruKind: Equatable, CaseIterable {
    case VIPViasatPremiumHD
    case base
    case child
    case adult
    case friendship
    case moviesAndSeries
    case matchFootballHD
    case mega4k
    case movies
    case knowledge
    case knowledgeHD
    case sport
    case beginner
    
    fileprivate var name: String {
        switch self {
        case .VIPViasatPremiumHD: return "ViP Viasat Premium"
        case .base: return "Базовый"
        case .child: return "Детский"
        case .adult: return "Для взрослых"
        case .friendship: return "Дружба"
        case .moviesAndSeries: return "Кино и сериалы"
        case .matchFootballHD: return "Матч! Футбол HD"
        case .mega4k: return "МЕГАП4K"
        case .movies: return "Настрой кино"
        case .knowledge: return "Познавательный"
        case .knowledgeHD: return "Познавательный HD"
        case .sport: return "Спорт"
        case .beginner: return "Стартовый"
        }
    }
}

internal struct Bundle2090000ru: ChannelsBundle {
    let kind: Bundle2090000ruKind
    let playlist: Playlist
    var name: String {kind.name}
    var id: AnyHashable { AnyHashable(name) }
}

internal extension Bundle2090000ru {
    static func load(in bundle: Bundle, of kind: Bundle2090000ruKind, adds: [M3UItem]) throws -> Self {
        let url = bundle.bundleURL
            .appendingPathComponent(kind.name, isDirectory: false)
            .appendingPathExtension("txt")
        let channels: [Channel2090000ru] = try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: .newlines)
            .compactMap { channel -> Channel2090000ru? in
                guard !channel.isEmpty else { return nil }
                guard let item = adds.first(where: { m3u -> Bool in
                    let title = m3u.title.lowercased()
                    let ch = channel.lowercased()
                    if title == ch  {
                        return true
                    }
                    if (title.hasPrefix(ch) || ch.hasPrefix(title)) {
                        if abs(ch.count - title.count) == 3 {
                            if ch.count > title.count {
                                if ch.hasSuffix(" hd") {
                                    return true
                                }
                            } else {
                                if title.hasSuffix(" hd") {
                                    return true
                                }
                            }
                        }
                    }
                    return false
                }) else {
                    return nil
                }
                return .init(name: channel, original: channel,
                    short: channel, stream: item.url, group: item.group)
            }
        let playlist = Playlist2090000ru(channels: channels)
        return .init(kind: kind, playlist: playlist)
    }
}
