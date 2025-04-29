//
//  IpTvProviderOttclub.swift
//  Channels
//
//  Created by Mikhail Demidov on 02.01.2023.
//

import Foundation

internal struct IpTvProviderOttclub: IpTvProvider {
    let kind: IpTvProviderKind
    let bundles: [ChannelsBundle] = []
    let baseBundles: [ChannelsBundle]
}

internal extension IpTvProviderOttclub {
    static func load(from bundle: Foundation.Bundle, apiKey: String) throws -> Self {
        let ottclub: IpTvProviderKind = .ottclub(key: apiKey)
        let url: URL = bundle.url(forResource: ottclub.resourcesName, withExtension: nil)!
        let resources = Foundation.Bundle(url: url)!
        let playlistURL = resources.url(forResource: playlistName, withExtension: nil)!
        let bundle = try BundleOttclub.load(url: playlistURL, apiKey: apiKey)
        return .init(kind: ottclub, baseBundles: [bundle])
    }
}

private extension IpTvProviderOttclub {
    static let playlistName = "playlist.m3u"
}
