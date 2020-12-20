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
        let channels = items.map { item -> ChannelDynamic in
            ChannelDynamic(name: item.title,
                stream: item.url, group: item.group)
        }
        
        let playlist = PlaylistDynamic(channels: Array(NSOrderedSet(array: channels).array as! [ChannelDynamic]));
        return .init(kind: .dynamic(m3u: m3u, name: name),
            bundles: [BundleDynamic(playlist: playlist, name: name)]
        )
    }
}
