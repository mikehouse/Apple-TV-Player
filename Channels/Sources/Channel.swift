//
//  Channel.swift
//  Channels
//
//  Created by Mikhail Demidov on 15.11.2020.
//

import Foundation

public protocol Channel {
    var name: String {get}
    var id: AnyHashable {get}
    var stream: URL {get}
    var group: String? {get}
}
