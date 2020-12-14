//
//  ChannelsICO.swift
//  Channels
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import Foundation
import CoreGraphics
import ImageIO

public protocol ChannelICOProvider {
    func ico(for channel: Channel) -> CGImage?
    func ico(for channel: Channel, locale: String) -> CGImage?
}

public struct ChannelICO: ChannelICOProvider {
    public let locale: String
    
    public init(locale: String) {
        self.locale = locale
    }
    
    public func ico(for channel: Channel) -> CGImage? {
        self.ico(for: channel, locale: locale)
    }
    
    public func ico(for channel: Channel, locale: String) -> CGImage? {
        ChannelsICO.ico(for: channel, locale: locale)
    }
}

private struct ChannelsICO {
    private static var cache: [AnyHashable: CGImage?] = [:]
    private static let bundle = Bundle(for: this_bundle_ref_class.self)
    private static let options = [kCGImageSourceShouldCache as String: kCFBooleanFalse] as CFDictionary
    
    static func ico(for channel: Channel, locale: String = "ru") -> CGImage? {
        let key = channel.id
        if let image = cache[key] {
            return image
        } else if cache.index(forKey: key) != nil {
            return nil
        } else {
            guard let resourcesURL = bundle.url(forResource: "channels-ico-\(locale)", withExtension: "bundle"),
                  let resources = Bundle(url: resourcesURL),
                  let imageURL = resources.url(forResource: channel.name, withExtension: "png"),
                  let source = CGImageSourceCreateWithURL(imageURL as CFURL, options),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                cache[channel.id] = .none
                return nil
            }
            cache[channel.id] = image
            return image
        }
    }
}
