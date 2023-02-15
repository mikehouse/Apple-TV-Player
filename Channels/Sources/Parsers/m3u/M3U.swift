//
//  M3U.swift
//  Channels
//
//  Created by Mikhail Demidov on 20.10.2020.
//

import Foundation
import os

public final class M3U {
    private let url: URL?
    private let data: Data
    private(set) public var items: [M3UItem] = []
    
    public init(url: URL) {
        self.url = url
        self.data = Data()
    }
    
    public init(data: Data) {
        self.data = data
        self.url = nil
    }
}

public extension M3U {
    @discardableResult
    func parse() throws -> [M3UItem] {
        if Thread.isMainThread {
            os_log(.info, "Non UI task called on UI thread.")
        }
        
        let data = try url.map({ try Data(contentsOf: $0) }) ?? self.data
        let string = String(data: data, encoding: .utf8)!
        let lines = string.components(separatedBy: .newlines)
        guard let firstLine = lines.first else {
            let error = NSError(domain: "com.tv.player", code: -1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Invalid M3U file format.", comment: "")
            ])
            throw error
        }
        guard firstLine.components(separatedBy: .whitespaces)
                  .filter({ !$0.isEmpty }).first == Directive.extm3u.rawValue else {
            let error = NSError(domain: "com.tv.player", code: -1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Invalid M3U header.", comment: "")
            ])
            throw error
        }
        var i = 0;
        var items: [M3UItem] = []
        while (true) {
            guard i < lines.count else {
                break
            }
            defer {
                i += 1
            }
            let line = lines[i]
            guard line.hasPrefix(Directive.extinf.rawValue) else {
                continue
            }
            var tagStart = 0
            var tags: [NSRange] = []
            var skipSplit = true
            var skipSplit2 = false
            for (idx, ch) in line.enumerated() {
                if idx <= Directive.extinf.rawValue.count {
                    // skip prefix.
                    continue
                }
                if idx == line.count - 1 {
                    if tagStart != 0 && idx - tagStart != 0 {
                        tags.append(.init(
                            location: tagStart + 1,
                            length: idx - tagStart))
                    }
                    continue
                }
                if (ch == " " || (tagStart != 0 && ch == ",")) {
                    if tagStart != 0 {
                        if skipSplit {
                            // case tag with white spaces.
                            continue
                        }
                        if idx - tagStart == 1 {
                            tagStart = idx
                            // case when two white spaces in row.
                        } else {
                            tags.append(.init(
                                location: tagStart + 1,
                                length: idx - tagStart - 1))
                            tagStart = idx
                            skipSplit = true
                            skipSplit2 = false
                        }
                    } else {
                        tagStart = idx
                    }
                } else {
                    if ch == "=" {
                        skipSplit = false
                    } else if ch == "\"" {
                        if !skipSplit2 {
                            skipSplit2 = true
                            skipSplit = true
                        } else {
                            skipSplit = false
                        }
                    }
                }
            }
            var group: String?
            var proxy: String?
            var logoURL: URL?
            var title: String = NSLocalizedString("title not found.", comment: "")
            let nsstring = line as NSString
            for range in tags {
                let tag = nsstring.substring(with: range)
                if tag.contains(M3U.Directive.group_title.rawValue) {
                    group = tag.components(separatedBy: "=")[1]
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    group = group.map({ $0.trimmingCharacters(in: .whitespaces) })
                } else if tag.contains(M3U.Directive.proxy.rawValue) {
                    proxy = tag.components(separatedBy: "=")[1]
                        .replacingOccurrences(of: "\"", with: "")
                } else if tag.contains(M3U.Directive.tvg_logo.rawValue) {
                    var logo: String = tag.components(separatedBy: "=")[1]
                        .replacingOccurrences(of: "\"", with: "")
                    logo = logo.trimmingCharacters(in: .whitespaces)
                    if logo.hasPrefix("http") {
                        logoURL = URL(string: logo)
                    }
                } else if !tag.contains("=") {
                    title = tag.trimmingCharacters(in: .whitespaces)
                }
            }
            i += 1
            let skip = [Directive.grp, .vlcopt]
            for _ in skip {
                guard i < lines.count else {
                    break
                }
                let next = lines[i].replacingOccurrences(of: " ", with: "")
                if skip.filter({ next.hasPrefix($0.rawValue) }).isEmpty == false {
                    i += 1
                }
            }
            guard i < lines.count else {
                break
            }
            let http = lines[i].replacingOccurrences(of: " ", with: "")
            guard (http.hasPrefix(Directive.http.rawValue) || http.hasPrefix(Directive.file.rawValue)),
                  let url = URL(string: http) else {
                continue
            }
            if let proxy = proxy.flatMap({ ProxyType(rawValue: $0) }) {
                do {
                    if let stream = try streamURL(from: proxy, source: url) {
                        let item = M3UItem(title: title, url: stream, group: group, logo: logoURL)
                        items.append(item)
                    }
                } catch {
                    os_log(.info, "cannot read stream proxy object \(error)")
                }
            } else {
                let item = M3UItem(title: title, url: url, group: group, logo: logoURL)
                items.append(item)
            }
        }
        
        self.items = items
        return items
    }
}

private extension M3U {
    enum Directive: String {
        case extm3u = "#EXTM3U"
        case extinf = "#EXTINF"
        case grp = "#EXTGRP"
        case vlcopt = "#EXTVLCOPT"
        case http
        case file // for unit tests mostly
        case group_title = "group-title="
        case tvg_logo = "tvg-logo="
        case proxy = "proxy=" // custom type. make additional logic for m3u.
    }
}

private func streamURL(from proxy: ProxyType, source: URL) throws -> URL? {
    do {
        let searchCache = ProxyCache(proxy: proxy, source: source, url: nil)
        if let cached = proxiesCache.first(where: { $0 == searchCache }) {
            if cached.stillValid, let url = cached.url {
                os_log(.info, "did read proxy from cache for %s value %s.", source.absoluteString, url.absoluteString)
                return url
            } else {
                os_log(.info, "proxy cache expired|invalid for %s.", source.absoluteString)
                proxiesCache.removeAll(where: { $0 == searchCache })
            }
        }
    }

    let data = try Data(contentsOf: source)
    let decoder = JSONDecoder()
    let object: ProxyTypeInterface
    switch proxy {
    case .stb:
        object = try decoder.decode(STB_proxy.self, from: data)
    }
    if let stream = object.url {
        os_log(.info, "proxy add cache for %s value %s.", source.absoluteString, stream.absoluteString)
        proxiesCache.append(.init(proxy: proxy, source: source, url: stream))
        return stream
    }
    return nil
}

private var proxiesCache: [ProxyCache] = []

private enum ProxyType: String {
    case stb
}

private protocol ProxyTypeInterface {
    var url: URL? {get}
}

private struct STB_proxy: Decodable, ProxyTypeInterface {
    let variants: [Variant]

    struct Variant: Decodable {
        let url: String
    }

    var url: URL? { variants.first.flatMap({ URL(string: $0.url + "&player=vlc") }) }
}

private final class ProxyCache: Equatable, ProxyTypeInterface {
    private let proxy: ProxyType
    private let source: URL

    let url: URL?

    private let created = Date()

    init(proxy: ProxyType, source: URL, url: URL?) {
        self.proxy = proxy
        self.source = source
        self.url = url
    }

    var stillValid: Bool {
        abs(Date().timeIntervalSince1970 - created.timeIntervalSince1970) < lifeTime
    }

    private var lifeTime: TimeInterval {
        switch proxy {
        case .stb:
            return TimeInterval(60 * 60 * 23)
        }
    }

    static func ==(lhs: ProxyCache, rhs: ProxyCache) -> Bool {
        if lhs.proxy != rhs.proxy {
            return false
        }
        if lhs.source != rhs.source {
            return false
        }
        return true
    }
}