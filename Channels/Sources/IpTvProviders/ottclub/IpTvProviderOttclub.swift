//
//  IpTvProviderOttclub.swift
//  Channels
//
//  Created by Mikhail Demidov on 02.01.2023.
//

import Foundation

internal struct IpTvProviderOttclub: IpTvProvider {
    let kind: IpTvProviderKind
    let bundles: [ChannelsBundle] = []
    let baseBundles: [ChannelsBundle]
    let favChannels: [Channel]
}

internal extension IpTvProviderOttclub {
    static func load(from bundle: Foundation.Bundle, apiKey: String) throws -> Self {
        let ottclub: IpTvProviderKind = .ottclub(key: apiKey)
        let url: URL = bundle.url(forResource: ottclub.resourcesName, withExtension: nil)!
        let resources = Foundation.Bundle(url: url)!
        let playlistURL = resources.url(forResource: playlistName, withExtension: nil)!
        let bundle = try BundleOttclub.load(url: playlistURL, apiKey: apiKey)
        let favChannels: [Channel] = [
            "ТНТ HD",
            "ТНТ(+2)",
            "Комедийное HD",
            "Премиальное HD",
            "FAN",
            "Хит HD",
            "2х2",
            "Дом Кино",
            "НСТ",
            "СТС HD",
            "Кинопремьера HD",
            "Кинокомедия HD",
            "Киносемья HD",
            "Киносвидание",
            "Кинохит HD",
            "Киномикс HD",
            "Киноужас HD",
            "Шокирующее HD",
            "Мужское кино",
            "TV1000 East HD",
            "TV1000 Action HD",
            "ViP Premiere HD",
            "ViP Megahit HD",
            "ViP Comedy HD",
            "ViP Serial HD",
            "CineMan Сваты HD",
            "CineMan HD",
            "CineMan Top HD",
            "CineMan Action HD",
            "CineMan Thriller HD",
            "CineMan Marvel HD",
            "CineMan Ужасы HD",
            "CineMan Comedy HD",
            "Fresh Rating HD",
            "Fresh Cinema HD",
            "Fresh Premiere HD",
            "Fresh Comedy HD",
            "Fresh Family HD",
            "Fresh Fantastic HD",
            "Fresh Series HD",
            "Fresh Horror HD",
            "Fresh Adventure HD",
            "Fresh Romantic HD",
            "Fresh Thriller HD",
            "Amedia Premium HD",
            "Amedia 1 HD",
            "Amedia Hit HD",
            "Fox HD",
            "Fox Life HD",
            "red HD",
            "sci-fi",
            "КиноТВ HD",
            "Кинопоказ HD",
            "Cinema",
            "Еврокино HD",
            "Plan B HD",
            "Остросюжетное HD",
            "Дом Кино Премиум HD",
            "Hollywood HD",
            "FilmBox Arthouse",
            "Блокбастер HD",
            "Star Cinema HD",
            "Star Family HD",
            "Kino 1 HD"
        ].map(FavChannel.init(name:))
        return .init(kind: ottclub,
            baseBundles: [bundle],
            favChannels: favChannels)
    }
}

private extension IpTvProviderOttclub {
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
        self.id = AnyHashable(name)
    }
}

