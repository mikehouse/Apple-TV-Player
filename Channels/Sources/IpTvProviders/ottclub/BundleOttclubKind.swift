//
//  BundleOttclubKind.swift
//  Channels
//
//  Created by Mikhail Demidov on 02.01.2023.
//

import Foundation

internal struct BundleOttclub: ChannelsBundle {
    let playlist: Playlist
    var name: String { "ottclub" }
    var id: AnyHashable { AnyHashable(name) }
}

internal extension BundleOttclub {
    static func load(url: URL, apiKey: String) throws -> Self {
        let rawString = try String(contentsOf: url)
        let data = rawString.replacingOccurrences(of: "API_KEY", with: apiKey).data(using: .utf8)!
        let m3uItems = try M3U(data: data).parse()
        let channels: [Channel] = m3uItems.map {item -> ChannelOttclub in
            ChannelOttclub(name: item.title,
                stream: item.url, group: item.group, logo: item.logo)
        }
        var base: [Channel] = []
        var movies: [Channel] = []
        var others: [Channel] = []
        for channel in channels {
            if channel.group == "Общие" {
                base.append(channel)
            } else if channel.group == "Кино" {
                movies.append(channel)
            } else {
                others.append(channel)
            }
        }
        let playlist = PlaylistOttclub(channels: base + movies + others)
        return .init(playlist: playlist)
    }
}

