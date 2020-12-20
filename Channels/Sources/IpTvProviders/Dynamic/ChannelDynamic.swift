//
//  ChannelDynamic.swift
//  Channels
//
//  Created by Mikhail Demidov on 28.11.2020.
//

import Foundation

internal struct ChannelDynamic: Channel, Hashable {
    let name: String
    let stream: URL
    let group: String?
    var id: AnyHashable { AnyHashable(name) }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func ==(lhs: ChannelDynamic, rhs: ChannelDynamic) -> Bool {
        return lhs.id == rhs.id
    }
}
