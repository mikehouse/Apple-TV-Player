//
//  ChannelsBundle.swift
//  Channels
//
//  Created by Mikhail Demidov on 27.11.2020.
//

import Foundation

public protocol ChannelsBundle {
    var playlist: Playlist {get}
    var name: String {get}
    var id: AnyHashable {get}
}
