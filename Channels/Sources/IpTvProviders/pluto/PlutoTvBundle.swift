//
//  PlutoTvBundle.swift
//  Channels
//
//  Created by Mikhail Demidov on 18.05.2025.
//

import Foundation
import class UIKit.UIDevice

struct PlutoTvBundle: ChannelsBundle {
    var playlist: Playlist
    var name: String
    var id: AnyHashable
}

extension PlutoTvBundle {
    static func load(bundle: Bundle) throws -> Self {
        let url = bundle.url(forResource: "playlist.m3u", withExtension: nil)!
        let rawString = try String(contentsOf: url)
        let sid = (UIDevice.current.identifierForVendor ?? UUID()).uuidString.lowercased()
        let data = rawString.replacingOccurrences(of: "SID_ID", with: sid).data(using: .utf8)!
        let m3uItems = try M3U(data: data).parse()
        let channels: [PlutoTvChannel] = m3uItems.map { item -> PlutoTvChannel in
            var channel = PlutoTvChannel(name: item.title, id: AnyHashable(item.title), stream: item.url, logo: item.logo)
            channel.original = channel.name
            channel.short = channel.name
            return channel
        }
        var uniq: [PlutoTvChannel] = []
        for channel in channels {
            if !uniq.contains(channel) {
                uniq.append(channel)
            }
        }
        let playlist = PlutoTvPlaylist(channels: uniq, name: "Pluto TV")
        return PlutoTvBundle(playlist: playlist, name: "Pluto TV", id: AnyHashable(playlist.name))
    }
}