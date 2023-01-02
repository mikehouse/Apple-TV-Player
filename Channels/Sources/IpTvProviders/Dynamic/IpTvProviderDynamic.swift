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
        let favs: FavoriteChannels = favPlaylists.first(where: { $0.playlistName == name }) ?? .default()
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
                    short: shortName, stream: item.url, group: item.group, logo: item.logo)
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
                "BACKUSTV Страшное HD",
                "BACKUSTV Страшное",
                "Backus TV",
                "Backus TV Страшное",
                "Paramount Comedy",
                "Дом Кино",
                "Ужастик",
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
                "Суббота! HD",
                "Суббота!",
                "ТВ-3 FHD",
                "ТВ-3 HD",
                "ТВ-3",
                "FilmTV Kinder",
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
                "Clubbing TV",
                "Кинозал (VHS 90s)",
                "Фантастика Sci-Fi",
                "KINDER TV"
        ], skipSourceURLs: [
            URL(string: "http://zabava-htlive.cdn.ngenix.net")!,
            URL(string: "https://okkotv-live.cdnvideo.ru")!,
            URL(string: "http://s5.sr-vk.online")!,
            URL(string: "http://78.58.133.179")!,
            URL(string: "http://94.154.83.88")!,
            URL(string: "http://bar-timeshift-inet.ll-bar.zsttk.ru")!,
        ], ignoreKeys: FavoriteChannels.default().ignoreKeys)
    }

    static func `default`() -> FavoriteChannels {
        return .init(playlistName: "", channelsNames: [],
            skipSourceURLs: [], ignoreKeys: [
            " [Not 24/7]",
            " [Geo-blocked]",
            " (1024p)",
            " (1080p)",
            " (1088p)",
            " (1090p)",
            " (10p)",
            " (112p)",
            " (1280p)",
            " (144p)",
            " (160p)",
            " (180p)",
            " (192p)",
            " (200p)",
            " (214p)",
            " (2160p)",
            " (220p)",
            " (226p)",
            " (234p)",
            " (240p)",
            " (260p)",
            " (270p)",
            " (272p)",
            " (276p)",
            " (280p)",
            " (288p)",
            " (294p)",
            " (298p)",
            " (302p)",
            " (304p)",
            " (320p)",
            " (326p)",
            " (350p)",
            " (352p)",
            " (360p)",
            " (384p)",
            " (392p)",
            " (394p)",
            " (396p)",
            " (400p)",
            " (404p)",
            " (406p)",
            " (410p)",
            " (414p)",
            " (416p)",
            " (420p)",
            " (432p)",
            " (450p)",
            " (460p)",
            " (472p)",
            " (476p)",
            " (480p)",
            " (484p)",
            " (486p)",
            " (504p)",
            " (514p)",
            " (528p)",
            " (540p)",
            " (542p)",
            " (552p)",
            " (560p)",
            " (576p)",
            " (578p)",
            " (582p)",
            " (600p)",
            " (614p)",
            " (640p)",
            " (642p)",
            " (648p)",
            " (684p)",
            " (704p)",
            " (712p)",
            " (714p)",
            " (718p)",
            " (720p)",
            " (768p)",
            " (804p)",
            " (854p)",
            " (864p)",
            " (900p)",
            " (908p)",
            " (956p)",
        ])
    }
}
