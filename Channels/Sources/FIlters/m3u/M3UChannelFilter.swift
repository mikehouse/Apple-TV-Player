//
//  M3UChannelFilter.swift
//  Channels
//
//  Created by Mikhail Demidov on 15.11.2020.
//

import Foundation

public final class M3UChannelFilter: ChannelFilter {
    public typealias Playlist = Channels.Playlist<M3UItem>
    private let acceptChannelsLists: [URL]
    
    public init(acceptChannelsLists: [URL]) {
        self.acceptChannelsLists = acceptChannelsLists
    }
    
    public func filter(playlist: Playlist) -> Playlist {
        let acceptTitles: [String] = acceptChannelsLists.flatMap { (url: URL) -> [String] in
            (try? String(contentsOf: url, encoding: .utf8))?
                .components(separatedBy: .newlines) ?? []
        }
        return .init(channels: playlist.channels.filter({ acceptTitles.contains($0.title) }))
    }
}
