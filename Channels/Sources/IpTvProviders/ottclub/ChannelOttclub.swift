//
//  ChannelOttclub.swift
//  Channels
//
//  Created by Mikhail Demidov on 02.01.2023.
//

import Foundation

internal class ChannelOttclub: Channel {
    let name: String
    let original: String
    let short: String
    let stream: URL
    let group: String?
    let logo: URL?
    let id: AnyHashable

    init(name: String, stream: URL, group: String?, logo: URL?) {
        self.name = name
        self.original = name
        self.short = name.replacingOccurrences(of: " HD", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "/", with: "-")
        self.stream = stream
        self.group = group
        self.logo = logo
        self.id = AnyHashable(name)
    }
}