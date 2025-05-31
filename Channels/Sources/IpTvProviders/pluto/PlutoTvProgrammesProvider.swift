//
//  PlutoTvProgrammesProvider.swift
//  Channels
//
//  Created by Mikhail Demidov on 18.05.2025.
//

import Foundation

final class PlutoTvProgrammesProvider: IpTvProgrammesProvider {

    internal static let shared = PlutoTvProgrammesProvider()

    internal var programmesRaw: [String: [(String, Date, Date)]] = [:]
    internal var programmes: [String: ChannelProgramme] = [:]

    func load(_ completion: @escaping (Error?) -> ()) {
        DispatchQueue.main.async {
            completion(nil)
        }
    }

    func list(for channel: Channel) -> ChannelProgramme? {
        if let list = programmes[channel.name] {
            return list
        }
        guard let tuple = programmesRaw.first(where: { k, v in k.contains(channel.name) })?.value else {
            return nil
        }
        programmes[channel.name] = ChannelProgramme(channel: channel, programmes: tuple.map { name, start, end in
            return .init(name: name, start: start, end: end)
        })
        return list(for: channel)
    }
}