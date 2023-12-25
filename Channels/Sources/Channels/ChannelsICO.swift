//
//  ChannelsICO.swift
//  Channels
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import Foundation
import CoreGraphics
import ImageIO

private let workQueue: OperationQueue = {
    let queue = OperationQueue()
    // If set > 1 then make sure for atomic access to
    // shared resources (local dictionary caches, etc.)
    // else crash will happen. It is a main reason
    // why it's set to 1.
    queue.maxConcurrentOperationCount = 1
    queue.qualityOfService = .userInitiated
    return queue
}()

public protocol ChannelICOProvider {
    func icoFetch(for channel: Channel, completion: @escaping (Error?, CGImage?) -> Void)
    func icoCancel(for channel: Channel)
}

private protocol ChannelICOFetcher {
    func icoBundle(for channel: Channel) -> CGImage?
    func icoBundle(for channel: Channel, locale: String) -> CGImage?
    func icoRemote(for channel: Channel, completion: @escaping (Error?, CGImage?) -> Void)
}

public class ChannelICO: ChannelICOProvider {
    public let locale: String
    
    public init(locale: String) {
        self.locale = locale
    }

    public func icoFetch(for channel: Channel, completion: @escaping (Error?, CGImage?) -> ()) {
        let operation = BlockOperation { [weak self] in
            guard let self else {
                return
            }
            if let image = self.icoBundle(for: channel) {
                DispatchQueue.main.async {
                    completion(nil, image)
                }
            } else {
                self.icoRemote(for: channel) { error, image in
                    DispatchQueue.main.async {
                        completion(error, image)
                    }
                }
            }
        }
        operation.name = String(describing: channel.id)
        workQueue.addOperation(operation)
    }

    public func icoCancel(for channel: Channel) {
        let key = String(describing: channel.id)
        for operation in workQueue.operations {
            if operation.name == key {
                operation.cancel()
            }
        }
    }
}

extension ChannelICO: ChannelICOFetcher {
    func icoBundle(for channel: Channel) -> CGImage? {
        self.icoBundle(for: channel, locale: locale)
    }

    func icoBundle(for channel: Channel, locale: String) -> CGImage? {
        ChannelsICOBundle.icoBundle(for: channel, locale: locale)
    }

    func icoRemote(for channel: Channel, completion: @escaping (Error?, CGImage?) -> ()) {
        ChannelsICORemote.icoRemote(for: channel, completion: completion)
    }
}

private struct ChannelsICORemote {
    private static let options = [kCGImageSourceShouldCache as String: kCFBooleanFalse] as CFDictionary
    private static var cache: [String:CGImage] = [:]

    static func icoRemote(for channel: Channel, completion: @escaping (Error?, CGImage?) -> ()) {
        workQueue.addOperation {
            assert(Thread.isMainThread == false)
            let key = channel.short
            if let image = cache[key] {
                return completion(nil, image)
            }
            if cache.index(forKey: key) != nil {
                return completion(nil, nil)
            }
            guard let url = channel.logo else {
                cache[key] = nil
                return completion(nil, nil)
            }
            do {
                let cacheDir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let cacheDirImage = cacheDir.appendingPathComponent("\(key).\(url.pathExtension)")
                if FileManager.default.fileExists(atPath: cacheDirImage.path),
                   let source = CGImageSourceCreateWithURL(cacheDirImage as CFURL, options),
                   let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    cache[key] = image
                    completion(nil, image)
                    return
                }

                let data = try Data(contentsOf: url)
                guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
                    return completion(nil, nil)
                }
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
                cache[key] = image
                if image != nil {
                    do {
                        try data.write(to: cacheDirImage)
                    } catch {
                        logger.error("\(error)")
                    }
                }
                completion(nil, image)
            } catch {
                completion(error, nil)
            }
        }
    }
}

private struct ChannelsICOBundle {
    private static var cache: [String: CGImage] = [:]
    private static let bundle = Bundle(for: this_bundle_ref_class.self)
    private static var bundleCache: [String:Bundle] = [:]
    private static let options = [kCGImageSourceShouldCache as String: kCFBooleanFalse] as CFDictionary

    static func icoBundle(for channel: Channel, locale: String = "ru") -> CGImage? {
        let key = channel.short
        if let image = cache[key] {
            return image
        } else if cache.index(forKey: key) != nil {
            return nil
        } else {
            guard let resources = bundleCache[locale] ?? findResourcesBundle(locale: locale) else {
                cache[key] = .none
                return nil
            }
            bundleCache[locale] = resources
            guard let imageURL = resources.url(forResource: channel.short, withExtension: "png"),
                  let source = CGImageSourceCreateWithURL(imageURL as CFURL, options),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                cache[key] = .none
                return nil
            }
            cache[key] = image
            return image
        }
    }

    private static func findResourcesBundle(locale: String) -> Bundle? {
        bundle.url(
            forResource: "channels-ico-\(locale)",
            withExtension: "bundle")
        .flatMap(Bundle.init(url:))
    }
}
