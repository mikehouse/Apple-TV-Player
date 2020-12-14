//
//  ChannelDynamic.swift
//  Channels
//
//  Created by Mikhail Demidov on 28.11.2020.
//

import Foundation

internal struct ChannelDynamic: Channel {
    let name: String
    let stream: URL
    let group: String?
    var id: AnyHashable { AnyHashable(name) }
}
