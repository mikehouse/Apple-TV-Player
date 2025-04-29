//
//  Channel.swift
//  Channels
//
//  Created by Mikhail Demidov on 15.11.2020.
//

import Foundation

public protocol Channel {
    // ex. "Bollywood HD (1080p) [Not 24/7] [Geo-blocked]"
    var name: String {get}
    // ex. "Bollywood HD (1080p)"
    var original: String {get}
    // ex. "Bollywood"
    var short: String {get}
    var id: AnyHashable {get}
    var stream: URL {get}
    var group: String? {get}
    var logo: URL? {get}
}
