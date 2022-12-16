//
//  ChannelDynamic.swift
//  Channels
//
//  Created by Mikhail Demidov on 28.11.2020.
//

import Foundation

internal struct ChannelDynamic: Channel, Hashable {
    let name: String
    let original: String
    let short: String
    let stream: URL
    let group: String?
    let logo: URL?
    var id: AnyHashable { AnyHashable(stream) }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(stream)
    }
    
    static func ==(lhs: ChannelDynamic, rhs: ChannelDynamic) -> Bool {
        return lhs.stream == rhs.stream
    }
}
