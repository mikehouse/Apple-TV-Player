//
//  PlutoTvProvider.swift
//  Channels
//
//  Created by Mikhail Demidov on 18.05.2025.
//

import Foundation

internal struct PlutoTvProvider: IpTvProvider {
    let kind: IpTvProviderKind
    let bundles: [ChannelsBundle]
    let baseBundles: [ChannelsBundle]
}

extension PlutoTvProvider {

    static func load(from bundle: Foundation.Bundle) throws -> Self {
        let kind: IpTvProviderKind = .plutoTv
        let url: URL = bundle.url(forResource: kind.resourcesName, withExtension: nil)!
        let resources = Foundation.Bundle(url: url)!
        let bundle: ChannelsBundle = try PlutoTvBundle.load(bundle: resources)
        return .init(kind: kind, bundles: [], baseBundles: [bundle])
    }
}
