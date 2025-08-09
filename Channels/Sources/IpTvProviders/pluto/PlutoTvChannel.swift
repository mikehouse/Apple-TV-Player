//
//  PlutoTvChannel.swift
//  Channels
//
//  Created by Mikhail Demidov on 18.05.2025.
//

import Foundation

struct PlutoTvChannel: Channel, Hashable {
    var name: String = ""
    var original: String = ""
    var short: String = ""
    var id: AnyHashable
    var stream: URL
    var group: String? = nil
    var logo: URL? = nil
    
    static func == (lhs: PlutoTvChannel, rhs: PlutoTvChannel) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
