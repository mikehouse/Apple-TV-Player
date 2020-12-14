//
//  BundleDynamic.swift
//  Channels
//
//  Created by Mikhail Demidov on 28.11.2020.
//

import Foundation

internal struct BundleDynamic: ChannelsBundle {
    let playlist: Playlist
    let name: String
    var id: AnyHashable { AnyHashable(name) }
}
