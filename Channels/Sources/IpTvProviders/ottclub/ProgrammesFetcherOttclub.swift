//
//  ProgrammesFetcherOttclub.swift
//  Channels
//
//  Created by Mikhail Demidov on 02.01.2023.
//

import Foundation
import os

internal final class ProgrammesFetcherOttclub: ProgrammesFetcherBase {

    override func fetch() {
        DispatchQueue.global(qos: .userInteractive).async {
            if let cacheFile = (try? self.cacheDirectory()).map({ $0.appendingPathComponent("epg.xml") }),
               FileManager.default.fileExists(atPath: cacheFile.path) {
                do {
                    os_log(.debug, "read from cache: %s", cacheFile.path)
                    try self.handle(xml: cacheFile)
                    return
                } catch {
                    os_log(.debug, "%s error: %s", cacheFile.path, String(describing: error))
                }
            }
            let url = URL(string: "http://myott.top/api/epg.xml.gz")!
            os_log(.debug, "no cache programme file found, gonna fetch new from %s", url.path)
            let xmlProvider = TeleguideInfoXmlProvider(url: url)
            xmlProvider.info { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case .failure(let error):
                    os_log(.debug, "%s error: %s", url.path, String(describing: error))
                    self.update(.failure(error))
                case .success(let url):
                    do {
                        let cacheDir = try self.cacheDirectory()
                        let cacheFile = cacheDir.appendingPathComponent(url.lastPathComponent, isDirectory: false)
                        if FileManager.default.fileExists(atPath: cacheFile.path) {
                            try FileManager.default.removeItem(at: cacheFile)
                        }
                        try FileManager.default.copyItem(at: url, to: cacheFile)
                        try self.handle(xml: cacheFile)
                    } catch {
                        os_log(.debug, "%s error: %s", url.path, String(describing: error))
                        self.update(.failure(error))
                    }
                }
            }
        }
    }

    private func handle(xml url: URL) throws {
        let parser = TeleguideInfoParser(url: url)
        let programmes = try parser.programme(from: Date(timeIntervalSinceNow: -(60 * 60 * 6)))
        guard programmes.isEmpty == false else {
            throw NSError(domain: "xml.outdated.error", code: -1, userInfo: [
                NSLocalizedDescriptionKey: url.path
            ])
        }
        update(.success(programmes))
    }

    private func cacheDirectory() throws -> URL {
        try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}

private final class FetchChannel: Channel {
    var name: String
    var original: String
    var short: String
    var id: AnyHashable
    var stream: URL
    var group: String?
    var logo: URL?

    convenience init(name: String) {
        self.init(name: name, original: name, short: name,
            id: name, stream: URL(fileURLWithPath: "/"), group: nil, logo: nil)
    }

    init(name: String, original: String, short: String,
         id: AnyHashable, stream: URL, group: String?, logo: URL?) {
        self.name = name
        self.original = original
        self.short = short
        self.id = id
        self.stream = stream
        self.group = group
        self.logo = logo
    }
}