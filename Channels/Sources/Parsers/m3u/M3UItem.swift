//
//  M3UItem.swift
//  Channels
//
//  Created by Mikhail Demidov on 20.10.2020.
//

import Foundation

public struct M3UItem: Equatable {
    public let title: String
    public let url: URL
    public let group: String?
    public let logo: URL?
    public let bandwidth: Int?
}
