//
//  Playlist.swift
//  Channels
//
//  Created by Mikhail Demidov on 15.11.2020.
//

import Foundation

public struct Playlist<T: Channel> {
    public let channels: [T]
    
    public init(channels: [T]) {
        self.channels = channels
    }
}
