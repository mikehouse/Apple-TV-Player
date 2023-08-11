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

    var object: ProxyTypeInterface = AnyProxyType(url: nil)
    switch proxy {
    case .stb:
        let data = try Data(contentsOf: source)
        let decoder = JSONDecoder()
        object = try decoder.decode(STB_proxy.self, from: data)
    case .onltvone_comedy:
        let group = DispatchGroup()
        group.enter()
        let hunter = createOnlTvOneComedyHunter(url: source) { result in
            switch result {
            case .success(let url):
                os_log(.info, "read 'onltvone_comedy' stream url %s", "\(url)")
                object = AnyProxyType(url: URL(string: url.absoluteString + "&player=vlc")!)
            case .failure(let error):
                os_log(.info, "error getting 'onltvone_comedy' stream url %s.", "\(error)")
            }
            group.leave()
        }
        hunter.hunt()
        print("-- START HUNT AND WAIT \(Thread.current) ---")
        group.wait()
        print("-- HUNT AFTER WAIT \(Thread.current) ---")
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
    case onltvone_comedy
}

private protocol ProxyTypeInterface {
    var url: URL? {get}
}

private struct AnyProxyType: ProxyTypeInterface {
    let url: URL?
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
        case .onltvone_comedy:
            return TimeInterval(60 * 60 * 2)
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

private func decodeBase64(encoded string: String) -> String {
    let data = Data(base64Encoded: string.data(using: .utf8)!)!
    return String(data: data, encoding: .utf8)!
}

// Base64 to not to be banned as sources are public.
private func createOnlTvOneComedyHunter(url: URL, result: @escaping (Result<URL, Error>) -> Void) -> PlaylistURLHunter {
    PlaylistURLHunter(
        source: url,
        playlistDomain: decodeBase64(encoded: "b25saW5ldHYub25l"),
        playlistPath: decodeBase64(encoded: "L2h0bWwvcGxheWVyLnBocA=="), onResult: result)
}

private final class PlaylistURLHunter: NSObject, WebViewProxyDelegate {

    let source: URL
    let playlistDomain: String
    let playlistPath: String
    private let onResult: (Swift.Result<URL, Error>) -> Void

    private var shouldStartLoad = true
    private lazy var urlSession = URLSession(configuration: .ephemeral)
    private lazy var webView = WebViewProxy()

    init(source: URL, playlistDomain: String, playlistPath: String, onResult: @escaping (Result<URL, Error>) -> ()) {
        self.source = source
        self.playlistDomain = playlistDomain
        self.playlistPath = playlistPath
        self.onResult = onResult
        super.init()
    }

    func hunt() {
        DispatchQueue.main.async { [self] in
            webView.delegate = self
            webView.load(.init(url: source))
        }
    }

    func didStartLoad() {
        shouldStartLoad = true
    }

    func didFinishLoad() {
        shouldStartLoad = false
    }

    func didFailLoadWithError(_ error: Swift.Error) {
        print(error)
        shouldStartLoad = false
    }

    func shouldStartLoad(with request: URLRequest) -> Bool {
        if let url = request.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           components.host == playlistDomain, components.path == playlistPath {
            shouldStartLoad = false
            let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
            var headers = HTTPCookie.requestHeaderFields(with: cookies)
            headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"
            headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
            headers["Accept-Encoding"] = "gzip, deflate, br"
            headers["Accept-Language"] = "en-GB,en-US;q=0.9,en;q=0.8"
            headers["Referer"] = source.absoluteString
            headers["Sec-Ch-Ua"] = "\"Not/A)Brand\";v=\"99\", \"Google Chrome\";v=\"115\", \"Chromium\";v=\"115\""
            headers["Sec-Ch-Ua-Mobile"] = "?0"
            headers["Sec-Ch-Ua-Platform"] = "\"macOS\""
            headers["Sec-Fetch-Dest"] = "iframe"
            headers["Sec-Fetch-Mode"] = "navigate"
            headers["Sec-Fetch-Site"] = "same-origin"
            headers["Upgrade-Insecure-Requests"] = "1"
            var request = URLRequest(url: url, timeoutInterval: 5)
            request.allHTTPHeaderFields = headers
            let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
                guard let self else {
                    return
                }
                if let error {
                    self.onResult(.failure(error))
                } else if let data {
                    do {
                        guard let html = String(data: data, encoding: .utf8) else {
                            return self.onResult(.failure(NSError(domain: "unknown.", code: -1)))
                        }
                        let regexString = "http.[^ \"]+"
                        var matches: [String] = []
                        if #available(tvOS 16.0, *) {
                            let regex = try Regex(regexString)
                            matches = html.matches(of: regex).map({ String(html[$0.range]) })
                        } else {
                            let regex = try NSRegularExpression(pattern: regexString)
                            let results = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                            matches = results.map { match in
                                    return (0..<match.numberOfRanges).map { range -> String in
                                        let rangeBounds = match.range(at: range)
                                        guard let range = Range(rangeBounds, in: html) else {
                                            return ""
                                        }
                                        return String(html[range])
                                    }
                                }.map({ $0.first }).filter({ $0 != nil }).map({ $0.unsafelyUnwrapped })
                        }
                        guard let url = matches.first(where: { url in
                                guard let url = URL(string: url),
                                      let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                                    return false
                                }
                                guard components.path.hasSuffix("playlist.m3u8") else {
                                    return false
                                }
                                return true
                            }).flatMap({ URL(string: $0) }) else {
                            self.onResult(.failure(NSError(domain: "source html playlist url not found.", code: -1)))
                            return
                        }
                        self.onResult(.success(url))
                    } catch {
                        self.onResult(.failure(error))
                    }
                } else {
                    self.onResult(.failure(NSError(domain: "unknown.", code: -1)))
                }
            }
            task.resume()
        }
        return shouldStartLoad
    }
}