//
//  M3UItem.swift
//  Channels
//
//  Created by Mikhail Demidov on 20.10.2020.
//

import Foundation

public struct M3UItem: Equatable, Channel {
    public let title: String
    public let url: URL
    public let group: String?
}
