//
//  IpTvProvider.swift
//  Channels
//
//  Created by Mikhail Demidov on 27.11.2020.
//

import Foundation
import CoreGraphics
import ImageIO

// TODO: hide this from public API.
public enum IpTvProviderKind: Hashable {
    // https://2090000.ru
    case ru2090000(key: String)
    // https://www.ottclub.tv
    case ottclub(key: String)
    case dynamic(m3u: Data, name: String)
    
    public var name: String {
        switch self {
        case .ru2090000:
            return "Электронный город (2090000.ru)"
        case .ottclub:
            return "ottclub"
        case .dynamic(_, name: let name):
            return name
        }
    }
    
    public var id: AnyHashable {
        switch self {
        case .ru2090000:
            return AnyHashable("ru2090000")
        case .ottclub:
            return AnyHashable("\(name)")
        case .dynamic(_, let name):
            return AnyHashable(name)
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func ==(lhs: IpTvProviderKind, rhs: IpTvProviderKind) -> Bool {
        lhs.id == rhs.id
    }
    
    internal var resourcesName: String {
        "\(self.id.base).bundle"
    }
    
    private var bundle: Bundle {
        Bundle(for: this_bundle_ref_class.self)
    }
    
    public var icon: CGImage? {
        guard let url = bundle.url(forResource: resourcesName, withExtension: nil),
              let resources = Bundle(url: url),
              let iconURL = resources.url(forResource: "favicon", withExtension: "png") else {
            return nil
        }
        
        let options = [kCGImageSourceShouldCache as String: kCFBooleanFalse] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(iconURL as CFURL, options) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    
    public static func builtInProviders() -> [IpTvProviderKind] {
        // Set your provider(s) here if needed.
        // Disabled by default.
        return []
    }
}

public protocol IpTvProvider {
    var kind: IpTvProviderKind { get }
    var bundles: [ChannelsBundle] { get }
    var baseBundles: [ChannelsBundle] { get }
    var favChannels: [Channel] { get }
}

public struct IpTvProviders {
    public static func kind(of kind: IpTvProviderKind) throws -> IpTvProvider {
        switch kind {
        case .ru2090000(let key):
            return try IpTvProvider2090000ru.load(
                from: Bundle(for: this_bundle_ref_class.self), apiKey: key)
        case .ottclub(let key):
            return try IpTvProviderOttclub.load(
                from: Bundle(for: this_bundle_ref_class.self), apiKey: key)
        case let .dynamic(data, name):
            return try IpTvProviderDynamic.load(m3u: data, name: name)
        }
    }
}

internal final class this_bundle_ref_class: NSObject {
}
