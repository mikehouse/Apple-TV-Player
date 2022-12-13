//
//  IpTvProviderDynamic.swift
//  Channels
//
//  Created by Mikhail Demidov on 28.11.2020.
//

import Foundation
import os

internal struct IpTvProviderDynamic: IpTvProvider {
    let kind: IpTvProviderKind
    let bundles: [ChannelsBundle]
    let baseBundles: [ChannelsBundle] = []
    let favChannels: [Channel] = []
}

internal extension IpTvProviderDynamic {
    static func load(m3u: Data, name: String) throws -> Self {
        let items = try M3U(data: m3u).parse()
        let favs: FavoriteChannels = favPlaylists.first(where: { $0.playlistName == name }) ?? .empty()
        let favsMap = favs.channelsNames.enumerated().reduce([Int:String]()) { (dict, pair) in
            return dict.merging([pair.offset:pair.element], uniquingKeysWith: { (l, r) in l })
        }
        let ignoreHosts: [String] = favs.skipSourceURLs.map({ $0.host ?? "" }).filter({ $0.isEmpty == false })
        var favoritesMap: [Int:[Channel]] = [:]
        var others: [Channel] = []
        items
            .forEach { item in
                if ignoreHosts.contains(item.url.host ?? "") {
                    return
                }
                var originalName = item.title
                for key in favs.ignoreKeys {
                    if originalName.contains(key) {
                        originalName = originalName.replacingOccurrences(of: key, with: "")
                    }
                }
                let shortName = originalName.hasSuffix(" HD") || originalName.hasSuffix(" hd")
                    ? String(originalName.dropLast(3)) : originalName
                let channel = ChannelDynamic(
                    name: item.title, original: originalName,
                    short: shortName, stream: item.url, group: item.group)
                if favs.channelsNames.contains(originalName),
                   let idx = favsMap.first(where: { $0.value == originalName })?.key {
                    favoritesMap[idx] = (favoritesMap[idx] ?? []) + [channel]
                } else {
                    others.append(channel)
                }
            }
        let favorites: [Channel] = favoritesMap.sorted(by: { (l, r) in l.key < r.key }).map({ $0.value }).flatMap({ $0 })
        let channels: [Channel] = favorites + others
        let playlist = PlaylistDynamic(channels: Array(NSOrderedSet(array: channels).array as! [ChannelDynamic]));
        return .init(kind: .dynamic(m3u: m3u, name: name),
            bundles: [BundleDynamic(playlist: playlist, name: name)]
        )
    }
}

/// Built-in playlist names.
/// These channels names will appear first in the playlist.
/// Please add your ones here with your unique name(s).
///
/// Lets say you have very long m3u file. For some interested channels
/// you have to scroll long enough to reach them. By having this favorites
/// channels list they will appear first in the playlist.
/// Just create your fav list (and add it to `favPlaylists` global list) as
/// ```swift
/// static func myFavs() -> FavoriteChannels {
///        return .init(
///              playlistName: "Name that you called your playlist",
///              channelsNames: ["CBS", "ABC"], // will appear first in the same order if found.
///              skipSourceURLs: [], // Some sources have region restrictions, filter them out.
///              ignoreKeys: [] // Some m3u sources add its unique data to names, strip them out.
///         )
///  }
/// ```
private class FavoriteChannels {

    let playlistName: String
    let channelsNames: [String]
    let skipSourceURLs: [URL]
    let ignoreKeys: [String]

    init(playlistName: String, channelsNames: [String], skipSourceURLs: [URL], ignoreKeys: [String]) {
        self.playlistName = playlistName
        self.channelsNames = channelsNames
        self.skipSourceURLs = skipSourceURLs
        self.ignoreKeys = ignoreKeys
    }
}

private let favPlaylists: [FavoriteChannels] = [
    FavoriteChannels.ruPlaylist()
]

extension FavoriteChannels {

    static func empty() -> FavoriteChannels {
        return .init(playlistName: "", channelsNames: [],
            skipSourceURLs: [], ignoreKeys: [])
    }

    static func ruPlaylist() -> FavoriteChannels {
        return .init(
            playlistName: "Russian channels list",
            channelsNames: [
                "ТНТ HD",
                "ТНТ",
                "ТНТ4 HD",
                "ТНТ4",
                "THT Exclusive HD",
                "THT Exclusive",
                "2x2 HD",
                "2x2",
                "Мульт",
                "Amedia Hit HD",
                "Amedia Hit",
                "Киномикс HD",
                "Киномикс",
                "Кинокомедия HD",
                "Кинокомедия",
                "Кинопремьера",
                "Киносвидание HD",
                "Киносвидание",
                "Киносемья",
                "Кинохит",
                "Пятница HD",
                "Пятница",
                "Суббота HD",
                "Суббота",
                "FilmTV Kinder",
                "BACKUSTV Страшное HD",
                "BACKUSTV Страшное",
                "Ужастик",
                "Hits 360 HD",
                "Hits 360",
                "V2Beat HD",
                "V2Beat",
                "Кухня ТВ HD",
                "Кухня ТВ",
                "Первый Музыкальный BY HD",
                "Первый Музыкальный BY",
                "Reload Radio Music Power HD",
                "Reload Radio Music Power",
                "Любимый HD",
                "Любимый",
                "Авто24",
                "ТЕХНО 24",
                "Fashion TV (SK)",
                "Backus TV",
                "Backus TV Страшное",
                "Clubbing TV",
                "Кинозал (VHS 90s)",
                "Фантастика Sci-Fi",
                "KINDER TV"
        ], skipSourceURLs: [
            URL(string: "http://zabava-htlive.cdn.ngenix.net")!,
            URL(string: "https://okkotv-live.cdnvideo.ru")!,
            URL(string: "http://s5.sr-vk.online")!
        ], ignoreKeys: [
            " [Not 24/7]",
            " [Geo-blocked]",
            " (1080p)",
            " (720p)",
            " (576p)",
            " (480p)",
            " (404p)"
        ])
    }
}
