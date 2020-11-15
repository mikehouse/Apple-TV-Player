//
//  ChannelFilter.swift
//  Channels
//
//  Created by Mikhail Demidov on 15.11.2020.
//

import Foundation

public protocol ChannelFilter {
    associatedtype Playlist
    func filter(playlist: Playlist) -> Playlist
}
