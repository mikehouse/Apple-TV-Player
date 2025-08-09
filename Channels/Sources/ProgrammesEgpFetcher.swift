//
//  ProgrammesFetcherOttclub.swift
//  Channels
//
//  Created by Mikhail Demidov on 02.01.2023.
//

import Foundation

internal final class ProgrammesEgpFetcher: ProgrammesFetcherBase {

    let id: String
    let url: URL

    init(id: String, url: URL) {
        self.id = id
        self.url = url
        super.init()
    }

    override func fetch() {
        DispatchQueue.global(qos: .userInteractive).async { [url, id] in
            let cacheFile = try! self.cacheDirectory().appendingPathComponent("\(id).epg.xml", isDirectory: false)
            if FileManager.default.fileExists(atPath: cacheFile.path) {
                do {
                    logger.debug("read from cache: \(cacheFile.path)")
                    try self.handle(xml: cacheFile)
                    return
                } catch {
                    logger.error("error for \(cacheFile.path): \(error)")
                }
            }
            logger.debug("no cache programme file found, gonna fetch new from \(url)")
            let xmlProvider = EgpProvider(url: url)
            xmlProvider.info { [weak self] result in
                guard let self else {
                    return
                }
                switch result {
                case .failure(let error):
                    logger.error("error for \(url.path): \(error)")
                    self.update(.failure(error))
                case .success(let url):
                    defer { try? FileManager.default.removeItem(at: url) }
                    do {
                        if FileManager.default.fileExists(atPath: cacheFile.path) {
                            try FileManager.default.removeItem(at: cacheFile)
                        }
                        try FileManager.default.copyItem(at: url, to: cacheFile)
                        try self.handle(xml: cacheFile)
                    } catch {
                        logger.error("error : \(error)")
                        self.update(.failure(error))
                    }
                }
            }
        }
    }

    private func handle(xml url: URL) throws {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            var date: Date?
            if let creationDate = attributes[.creationDate] as? Date {
                date = creationDate
            }
            if let modificationDate = attributes[.modificationDate] as? Date {
                date = modificationDate
            }
            if let date {
                let now = Date()
                let startOfWorkWeek = Calendar.current.component(.weekday, from: now) == 2 ||
                    Calendar.current.component(.weekday, from: now) == 3
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)
                let before10Hours = Calendar.current.date(byAdding: .hour, value: -10, to: now)
                if let before = startOfWorkWeek ? before10Hours : yesterday {
                    if date < before {
                        logger.info("Last programmes update was at \(date), try download new programmes list...")
                        throw NSError(domain: "xml.outdated.error", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: url.path
                        ])
                    }
                }
            } else {
                logger.warning("Cannot read last changes date for: \(url.path)")
            }
        } catch {
            throw error
        }

        let parser = EgpParser(url: url)
        let programmes = try parser.programme(from: Date(timeIntervalSinceNow: -(60 * 60 * 6)))
        update(.success(programmes))
    }

    private func cacheDirectory() throws -> URL {
        try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}
