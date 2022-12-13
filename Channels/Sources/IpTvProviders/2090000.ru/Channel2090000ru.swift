//
//  Channel2090000ru.swift
//  Channels
//
//  Created by Mikhail Demidov on 27.11.2020.
//

import Foundation

internal struct Channel2090000ru: Channel {
    let name: String
    let original: String
    let short: String
    let stream: URL
    let group: String?
    var id: AnyHashable { AnyHashable(name.lowercased()) }
}
