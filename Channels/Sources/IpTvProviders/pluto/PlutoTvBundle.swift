//
//  PlutoTvBundle.swift
//  Channels
//
//  Created by Mikhail Demidov on 18.05.2025.
//

import Foundation

struct PlutoTvBundle: ChannelsBundle {
    var playlist: Playlist
    var name: String
    var id: AnyHashable
}

extension PlutoTvBundle {
    static func load(bundle: Bundle) throws -> Self {
        let playlistUrl = bundle.url(forResource: "playlist.m3u", withExtension: nil)!
        let m3uItems = try M3U(url: playlistUrl).parse()
        let channels: [Channel] = m3uItems.map { item -> PlutoTvChannel in
            var channel = PlutoTvChannel(name: item.title, id: AnyHashable(item.title), stream: item.url)
            channel.original = channel.name
            channel.short = channel.name
            return channel
        }
        let playlist = PlutoTvPlaylist(channels: channels, name: "Pluto TV")
        return PlutoTvBundle(playlist: playlist, name: "Pluto TV", id: AnyHashable(playlist.name))
    }
}