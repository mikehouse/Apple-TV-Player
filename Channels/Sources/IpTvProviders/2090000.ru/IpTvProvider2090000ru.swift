//
//  IpTvProvider2090000ru.swift
//  Channels
//
//  Created by Mikhail Demidov on 27.11.2020.
//

import Foundation

internal struct IpTvProvider2090000ru: IpTvProvider {
    let kind: IpTvProviderKind
    let bundles: [ChannelsBundle]
    let baseBundles: [ChannelsBundle]
    let favChannels: [Channel]
}

internal extension IpTvProvider2090000ru {
    static func load(from bundle: Foundation.Bundle, apiKey: String) throws -> Self {
        let provider = IpTvProviderKind.ru2090000(key: apiKey)
        let url: URL = bundle.url(forResource:provider.resourcesName, withExtension: nil)!
        let resources = Foundation.Bundle(url: url)!
        let playlistURL = resources.url(forResource: playlistName, withExtension: nil)!
        let rawString = try String(contentsOf: playlistURL)
        let data = rawString.replacingOccurrences(of: "API_KEY", with: apiKey).data(using: .utf8)!
        let m3uItems = try M3U(data: data).parse()
        let bundles: [Bundle2090000ru] = Bundle2090000ruKind.allCases.compactMap { kind -> Bundle2090000ru? in
            try? Bundle2090000ru.load(in: resources, of: kind, adds: m3uItems)
        }
        let base: [Bundle2090000ruKind] = [.beginner, .base]
        let favChannels: [Channel] = [
            "Paramount Comedy HD",
            "ТНТ HD",
            "Europa Plus TV",
            "СТС",
            "Дом кино",
            "Кинокомедия",
            "Кино ТВ HD",
            "СТС love",
            "Настоящее страшное Телевидение",
            "Еврокино",
            "ТВ-3",
            "Ю",
            "Пятница",
            "Disney Channel",
            "Че!",
            "Nickelodeon",
            "Русский детектив",
            "Первый HD"
        ].map(FavChannel.init(name:))
        return .init(kind: provider, bundles: bundles,
            baseBundles: bundles.filter({ base.contains($0.kind) }),
            favChannels: favChannels)
    }
}

private extension IpTvProvider2090000ru {
    static let playlistName = "playlist.m3u"
}

private final class FavChannel: Channel {
    let name: String
    let original: String
    let short: String
    let id: AnyHashable
    var stream: URL {fatalError()}
    var logo: URL?
    var group: String? = nil
    
    init(name: String) {
        self.name = name
        self.original = name
        self.short = name
        self.id = AnyHashable(name.lowercased())
    }
}
