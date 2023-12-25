//
//  Playlist.swift
//  Channels
//
//  Created by Mikhail Demidov on 27.11.2020.
//

import Foundation
import os

let logger = Logger()

public protocol Playlist {
    var channels: [Channel] {get}
}
