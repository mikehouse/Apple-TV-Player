//
//  PlutoTvChannel.swift
//  Channels
//
//  Created by Mikhail Demidov on 18.05.2025.
//

import Foundation

struct PlutoTvChannel: Channel {
    var name: String = ""
    var original: String = ""
    var short: String = ""
    var id: AnyHashable
    var stream: URL
    var group: String? = nil
    var logo: URL? = nil
}