//
//  M3U.swift
//  Channels
//
//  Created by Mikhail Demidov on 20.10.2020.
//

import Foundation
import class UIKit.UIDevice

public final class M3U {
    private let url: URL?
    private let data: Data
    private let streamFormatAccept: (String) -> Bool
    private(set) public var items: [M3UItem] = []
    
    public init(url: URL, streamFormatAccept: @escaping (String) -> Bool = { _ in false }) {
        self.url = url
        self.streamFormatAccept = streamFormatAccept
        self.data = Data()
    }
    
    public init(data: Data, streamFormatAccept: @escaping (String) -> Bool = { _ in false }) {
        self.data = data
        self.streamFormatAccept = streamFormatAccept
        self.url = nil
    }

    private lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private lazy var lock = NSLock()
}

public extension M3U {

    private func parseTags(string: String) -> [String] {
        var string = string
        let spaceDelimiter = " "
        let commaDelimiter = ","
        let quote = "\""
        let spaceDelimiterChar = Character(spaceDelimiter)
        let commaDelimiterChar = Character(commaDelimiter)
        let quoteChar = Character(quote)

        var lastTag: String?
        if string.filter({ $0 == commaDelimiterChar }).count == 1 {
            let pair = string.components(separatedBy: commaDelimiter)
            string = pair[0]
            lastTag = pair[1]
        }

        var tags: [String] = []
        var tag = ""
        var tagStarted = false
        var delimiterIsSpace = false
        var delimiterIsComma = false
        var delimiterUnknown = false
        var quoteStarted = false
        var idx = 0
        while idx < string.count {
            let ch = string[string.index(string.startIndex, offsetBy: idx)]
            if ch == quoteChar {
                quoteStarted = !quoteStarted
            }
            if !tagStarted, ch == spaceDelimiterChar {
                delimiterIsSpace = true
                tagStarted = true
                idx += 1
                continue
            } else if !tagStarted, ch == commaDelimiterChar {
                delimiterIsComma = true
                tagStarted = true
                idx += 1
                continue
            } else if idx == 0 {
                delimiterUnknown = true
                tagStarted = true
                tag.append(ch)
                idx += 1
                continue
            }
            guard tagStarted else {
                print("should not be here")
                continue
            }
            if delimiterUnknown {
                if ch == spaceDelimiterChar {
                    tagStarted = false
                    delimiterUnknown = false
                } else if ch == commaDelimiterChar {
                    tagStarted = false
                    delimiterUnknown = false
                }
            } else if delimiterIsSpace {
                if ch == spaceDelimiterChar, !quoteStarted {
                    tagStarted = false
                    delimiterIsSpace = false
                }
            } else if delimiterIsComma {
                if ch == commaDelimiterChar {
                    tagStarted = false
                    delimiterIsComma = false
                }
            }
            guard tagStarted else {
                tags.append(tag)
                tag = ""
                continue
            }
            tag.append(ch)
            idx += 1
        }
        if !tag.isEmpty {
            tags.append(tag)
            tag = ""
        }
        if let lastTag {
            tags.append(lastTag)
        }
        tags = tags.map({ tag in
            var tag = tag
            while true {
                if tag.hasSuffix(spaceDelimiter) || tag.hasSuffix(commaDelimiter) {
                    tag = String(tag.dropLast())
                    continue
                }
                if tag.hasPrefix(spaceDelimiter) || tag.hasPrefix(commaDelimiter) {
                    tag = String(tag.dropFirst())
                    continue
                }
                break
            }
            return tag
        })
        return tags
    }

    @discardableResult
    func parse() throws -> [M3UItem] {
        if Thread.isMainThread {
            logger.warning("Non UI task called on UI thread.")
        }
        
        let data = try url.map({ try Data(contentsOf: $0) }) ?? self.data
        let string = String(data: data, encoding: .utf8)!
        let lines = string.components(separatedBy: .newlines).filter({ !$0.isEmpty })
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
            guard line.hasPrefix(Directive.extinf.rawValue) || line.hasPrefix(Directive.stream.rawValue) else {
                continue
            }
            let prefixDir: Directive = line.hasPrefix(Directive.extinf.rawValue) ? .extinf : .stream
            let tags = parseTags(string: "\(line.dropFirst(prefixDir.rawValue.count + 1))")
            var group: String?
            var proxy: String?
            var logoURL: URL?
            var title: String = ""
            var bandwidth: Int?
            for tag in tags {
                if tag.hasPrefix(M3U.Directive.group_title.rawValue) {
                    group = tag.components(separatedBy: "=")[1]
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    group = group.map({ $0.trimmingCharacters(in: .whitespaces) })
                } else if tag.hasPrefix(M3U.Directive.proxy.rawValue) {
                    proxy = tag.components(separatedBy: "=")[1]
                        .replacingOccurrences(of: "\"", with: "")
                } else if tag.hasPrefix(M3U.Directive.bandwidth.rawValue) {
                    bandwidth = Int(tag.components(separatedBy: "=")[1])
                } else if tag.hasPrefix(M3U.Directive.tvg_logo.rawValue) {
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
            let maybeStreamUrl = lines[i].replacingOccurrences(of: " ", with: "")
            guard (maybeStreamUrl.hasPrefix(Directive.http.rawValue)
                || maybeStreamUrl.hasPrefix(Directive.file.rawValue))
                || streamFormatAccept(maybeStreamUrl) else {
                continue
            }
            guard let url = URL(string: maybeStreamUrl) else {
                continue
            }
            if let proxy = proxy.flatMap({ ProxyType(rawValue: $0) }) {
                queue.addOperation { [lock, title, group, bandwidth] in
                    do {
                        if let stream = try streamURL(from: proxy, source: url) {
                            let item = M3UItem(title: title, url: stream, group: group, logo: logoURL, bandwidth: bandwidth)
                            lock.lock()
                            items.append(item)
                            lock.unlock()
                        }
                    } catch {
                        logger.error("cannot read stream proxy object for \(maybeStreamUrl): \(error)")
                    }
                }
            } else {
                let item = M3UItem(title: title, url: url, group: group, logo: logoURL, bandwidth: bandwidth)
                items.append(item) // Make sure that playlist does not have `proxy` else we need also `lock` here.
            }
        }

        queue.waitUntilAllOperationsAreFinished()
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
        case stream = "#EXT-X-STREAM-INF"
        case http
        case file // for unit tests mostly
        case group_title = "group-title="
        case tvg_logo = "tvg-logo="
        case bandwidth = "BANDWIDTH="
        case proxy = "proxy=" // custom type. make additional logic for m3u.
    }
}

private let plutoISODateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions.insert(.withFractionalSeconds)
    return formatter
}()

private let userFormatter: DateFormatter = {
    let userFormatter = DateFormatter()
    userFormatter.dateFormat = "HH:mm"
    return userFormatter
}()


private final class PlutoDateFormatter: DateFormatter, @unchecked Sendable {

    private lazy var formatter = plutoISODateFormatter

    override func date(from string: String) -> Date? {
        plutoISODateFormatter.date(from: string)
    }

    override func string(from date: Date) -> String {
        plutoISODateFormatter.string(from: date)
    }
}

private struct PlutoChannelCredentials: Decodable {
    let stitcherParams: String
    let sessionToken: String
    let EPG: [PlutoChannel]?
}

private struct PlutoChannel: Decodable {
    let name: String
    let timelines: [TimeLine]

    struct TimeLine: Decodable {
        let start: Date
        let stop: Date
        let title: String
        let episode: Episode?

        struct Episode: Decodable {
            let name: String
        }
    }
}

private let urlSession = URLSession(configuration: .ephemeral)

private func streamURL(from proxy: ProxyType, source: URL) throws -> URL? {
    do {
        let searchCache = ProxyCache(proxy: proxy, source: source, url: nil)
        proxiesCacheLock.lock()
        defer { proxiesCacheLock.unlock() }
        if let cached = proxiesCache.first(where: { $0 == searchCache }) {
            if cached.stillValid, let url = cached.url {
                logger.info("did read proxy from cache for \(source.absoluteString) value \(url.absoluteString).")
                return url
            } else {
                logger.info("proxy cache expired|invalid for \(source.absoluteString).")
                proxiesCache.removeAll(where: { $0 == searchCache })
            }
        }
    }

    var object: ProxyTypeInterface = AnyProxyType(url: nil)
    switch proxy {
    case .pluto:
        var headers: [String: String] = [:]
        headers["accept"] = "*/*"
        headers["accept-language"] = "en-GB,en;q=0.9"
        headers["origin"] = decodeBase64(encoded: "aHR0cHM6Ly9wbHV0by50dg==")
        headers["priority"] = "u=1, i"
        headers["referer"] = "\(decodeBase64(encoded: "aHR0cHM6Ly9wbHV0by50dg=="))/"
        headers["sec-ch-ua"] = "\"Chromium\";v=\"136\", \"Google Chrome\";v=\"136\", \"Not.A/Brand\";v=\"99\""
        headers["sec-ch-ua-mobile"] = "?0"
        headers["sec-ch-ua-platform"] = "\"macOS\""
        headers["sec-fetch-dest"] = "empty"
        headers["sec-fetch-mode"] = "cors"
        headers["sec-fetch-site"] = "same-site"
        headers["user-agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/136.0.0.0 Safari/537.36"
        let credentials: PlutoChannelCredentials
        do {
            let dateFormatter = PlutoDateFormatter()
            let date = dateFormatter.string(from: Date())
            var credentialsComponents = URLComponents(
                // hide behind base64 base url not to get banned by TV provider if it scans Github.
                url: URL(string: decodeBase64(encoded: "aHR0cHM6Ly9ib290LnBsdXRvLnR2L3Y0L3N0YXJ0"))!,
                resolvingAgainstBaseURL: false
            )!
            credentialsComponents.queryItems = [
                URLQueryItem(name: "appName", value: "web"),
                URLQueryItem(name: "appVersion", value: "9.12.0-e2425380b67be936b703637b779ede1dc68f15fd"),
                URLQueryItem(name: "deviceVersion", value: "136.0.0"),
                URLQueryItem(name: "deviceModel", value: "web"),
                URLQueryItem(name: "deviceMake", value: "chrome"),
                URLQueryItem(name: "deviceType", value: "web"),
                URLQueryItem(name: "clientID", value: (UIDevice.current.identifierForVendor ?? UUID()).uuidString.lowercased()),
                URLQueryItem(name: "clientModelNumber", value: "1.0.0"),
                URLQueryItem(name: "serverSideAds", value: "false"),
                URLQueryItem(name: "drmCapabilities", value: "widevine:L3"),
                URLQueryItem(name: "blockingMode", value: ""),
                URLQueryItem(name: "notificationVersion", value: "1"),
                URLQueryItem(name: "appLaunchCount", value: "0"),
                URLQueryItem(name: "lastAppLaunchDate", value: date),
                URLQueryItem(name: "clientTime", value: date),
                URLQueryItem(name: "channelSlug", value: source.lastPathComponent),
            ]
            let credentialsUrl = credentialsComponents.url!
//            logger.debug("Download credentials: \(credentialsUrl.absoluteString)")
            var request = URLRequest(url: credentialsUrl)
            request.allHTTPHeaderFields = headers
            var error: Error?
            var data: Data?
            let group = DispatchGroup()
            group.enter()
            urlSession.dataTask(with: request) { d, _, e in
                data = d
                error = e
                group.leave()
            }.resume()
            group.wait()
            if let error {
                throw error
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            let creds = try decoder.decode(PlutoChannelCredentials.self, from: data!)
            credentials = PlutoChannelCredentials(
                stitcherParams: creds.stitcherParams.replacingOccurrences(of: "\\u0026", with: "&"),
                sessionToken: creds.sessionToken,
                EPG: creds.EPG
            )

            for epg in credentials.EPG ?? [] {
                var list: [(String, Date, Date)] = []
                for timeline in epg.timelines {
                    list.append(("\(timeline.title)\(timeline.episode.map({ " (ep. \($0.name))" }) ?? "")", timeline.start, timeline.stop))
                }
                PlutoTvProgrammesProvider.shared.programmesRaw[epg.name] = list
            }
        }
        let basePath = URL(string: decodeBase64(encoded: "aHR0cHM6Ly9jZmQtdjQtc2VydmljZS1jaGFubmVsLXN0aXRjaGVyLXVzZTEtMS5wcmQucGx1dG8udHYvdjIvc3RpdGNoL2hscy9jaGFubmVs"))!
        let baseURL = basePath.appendingPathComponent(source.lastPathComponent)
        var stream = URL(string: "\(baseURL.absoluteString)/master.m3u8?\(credentials.stitcherParams)")!
        stream = stream.absoluteString.removingPercentEncoding.flatMap({ URL(string: $0) }) ?? stream
        // Will contain such queries:
        // advertisingId, appName, appVersion, app_name, clientDeviceType, clientID, clientModelNumber, country
        // deviceDNT, deviceId, deviceLat, deviceLon, deviceMake, deviceModel, deviceType, deviceVersion
        // marketingRegion, serverSideAds, sessionID, sid, userId
        var streamComponents = URLComponents(url: stream, resolvingAgainstBaseURL: false)!
        var streamQueries: [URLQueryItem] = streamComponents.queryItems ?? []
        streamQueries.append(.init(name: "jwt", value: credentials.sessionToken))
        streamQueries.append(.init(name: "masterJWTPassthrough", value: "true"))
        streamQueries.append(.init(name: "includeExtendedEvents", value: "true"))
        streamComponents.queryItems = streamQueries
        var request = URLRequest(url: streamComponents.url!)
        request.allHTTPHeaderFields = headers
//        logger.debug("\(streamComponents.url!.absoluteString)")
        var error: Error?
        var data: Data?
        Thread.sleep(forTimeInterval: 0.5)
        let group = DispatchGroup()
        group.enter()
        urlSession.dataTask(with: request) { d, _, e in
            data = d
            error = e
            group.leave()
        }.resume()
        group.wait()
        if let error {
            throw error
        }
        let m3u = M3U(data: data!) { maybeURL in
            URL(string: maybeURL) != nil
        }
        try m3u.parse()
        guard !m3u.items.isEmpty else {
            throw NSError(domain: "m3u.empty", code: -1, userInfo: [
                NSLocalizedDescriptionKey: source.absoluteString
            ])
        }
        let items = m3u.items.sorted(by: { $0.bandwidth ?? 0 > $1.bandwidth ?? 0 })
        var streamURL = baseURL.appendingPathComponent(items[0].url.absoluteString)
        streamURL = streamURL.absoluteString.removingPercentEncoding.flatMap({ URL(string: $0) }) ?? streamURL
        object = AnyProxyType(url: streamURL)
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
                logger.info("read 'onltvone_comedy' stream url \(url)")
                object = AnyProxyType(url: URL(string: url.absoluteString)!)
            case .failure(let error):
                logger.error("error getting 'onltvone_comedy' stream url\(error).")
            }
            group.leave()
        }
        hunter.hunt()
        group.wait()
    }
    if let stream = object.url {
        logger.info("proxy add cache for \(source.absoluteString) value \(stream.absoluteString).")
        proxiesCacheLock.lock()
        proxiesCache.append(.init(proxy: proxy, source: source, url: stream))
        proxiesCacheLock.unlock()
        return stream
    }
    return nil
}

private var proxiesCache: [ProxyCache] = []
private var proxiesCacheLock = NSLock()

private enum ProxyType: String {
    case stb
    case pluto
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
        case .onltvone_comedy, .pluto:
            return TimeInterval(60 * 1)
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
        playlistDomain: decodeBase64(encoded: "dHZvbmxpbmUubGl2ZQ=="),
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
        logger.error("\(error)")
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
                                guard components.path.hasSuffix(".m3u8") else {
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