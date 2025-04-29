//
//  IpTvProviderDynamic.swift
//  Channels
//
//  Created by Mikhail Demidov on 28.11.2020.
//

import Foundation

internal struct IpTvProviderDynamic: IpTvProvider {
    let kind: IpTvProviderKind
    let bundles: [ChannelsBundle]
    let baseBundles: [ChannelsBundle] = []
}

internal extension IpTvProviderDynamic {
    static func load(m3u: Data, name: String) throws -> Self {
        let items = try M3U(data: m3u).parse()
        let channels: [Channel] = items.map({ item in
            var originalName = item.title
            for key in stripRestrictionKeys {
                if originalName.contains(key) {
                    originalName = originalName.replacingOccurrences(of: key, with: "")
                }
            }
            var shortName = originalName
            for key in stripQualityKeys {
                if shortName.contains(key) {
                    shortName = shortName.replacingOccurrences(of: key, with: "")
                }
            }
            return ChannelDynamic(
                name: item.title, original: originalName,
                short: shortName, stream: item.url, group: item.group, logo: item.logo)
        })
        let playlist = PlaylistDynamic(channels: channels, name: name);
        return .init(kind: .dynamic(m3u: m3u, name: name), bundles: [BundleDynamic(playlist: playlist, name: name)])
    }
}

private let stripRestrictionKeys = [
    " [Not 24/7]",
    " [Geo-blocked]"
]
private let stripQualityKeys = [
    " HD",
    " FHD",
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
]
