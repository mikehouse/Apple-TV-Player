//
//  TeleguideInfoParserTests.swift
//  ChannelsTests
//
//  Created by Mikhail Demidov on 22.01.2023.
//

import XCTest

@testable import Channels

final class TeleguideInfoParserTests: XCTestCase {

    private var downloadMode = false

    func testParseXmlChannels() throws {
        let testExpectation = expectation(description: "channels")
        parseChannels { result in
            switch result {
            case .failure(let error):
                XCTFail(String(describing: error))
            case .success(let channels):
                XCTAssertEqual(channels.count, 390)
            }
            testExpectation.fulfill()
        }
        wait(for: [testExpectation], timeout: 20)
    }

    func testParseXmlProgrammes() throws {
        let testExpectation = expectation(description: "programmes")
        // 2023/01/23 03:00:00 Unix epoch since 1970.
        let fromDate = Date(timeIntervalSince1970: 1674442800)
        parseProgrammes(from: fromDate) { result in
            switch result {
            case .failure(let error):
                XCTFail(String(describing: error))
            case .success(let programmes):
                // Some channels (all amount is 390) do not have programmes since `from` date.
                XCTAssertEqual(programmes.count, 296)
                for i in 0...5 {
                    let programme = programmes[i]
                    XCTAssertFalse(programme.programmes.isEmpty)
                    for p in programme.programmes {
                        if p.start < fromDate {
                            XCTFail()
                            defer { testExpectation.fulfill() }
                            return
                        }
                    }
                }
            }
            testExpectation.fulfill()
        }
        // M1 Pro MacBook takes around 13 seconds to parse big test xml file.
        wait(for: [testExpectation], timeout: 30)
    }

    func testParseXmlChannelsLogoDownloads() throws {
        guard downloadMode else {
            return
        }
        let testExpectation = expectation(description: "downloads")
        parseChannels { result in
            switch result {
            case .failure(let error):
                XCTFail(String(describing: error))
            case .success(let channels):
                let bundle = Bundle(for: Channels.M3U.self).url(forResource: "ottclub", withExtension: "bundle")!
                let url = Bundle(url: bundle)!.url(forResource: "playlist", withExtension: "m3u")!
                let m3u = M3U(url: url)
                do {
                    try m3u.parse()
                } catch {
                    XCTFail(String(describing: error))
                }
                XCTAssertFalse(m3u.items.isEmpty)
                let manager = FileManager.default
                let dest = manager.temporaryDirectory.appendingPathComponent("logos")
                if manager.fileExists(atPath: dest.path) == false {
                    try! manager.createDirectory(at: dest, withIntermediateDirectories: true)
                }
                let names = Set(m3u.items.map(\.title))
                for channel in channels {
                    guard names.contains(channel.name) else {
                        print("Skip: \(channel.name)")
                        continue
                    }
                    guard let logo = channel.logo else {
                        print("No logo URL found: \(channel.name)")
                        continue
                    }
                    do {
                        let path = dest.appendingPathComponent(channel.short).appendingPathExtension("png")
                        if manager.fileExists(atPath: path.path) {
                            print("Logo already exists \(path.lastPathComponent)")
                            continue
                        }
                        print("\(channel.name): loading logo at \(logo)")
                        let data = try Data(contentsOf: logo)
                        try data.write(to: path)
                    } catch {
                        print(error)
                    }
                }
            }
            testExpectation.fulfill()
        }
        wait(for: [testExpectation], timeout: 500)
    }

    private func parseChannels(_ completion: @escaping (Swift.Result<[Channel], Error>) -> Void) {
        parse { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let parser):
                do {
                    let channels = try parser.channels()
                    completion(.success(channels))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func parseProgrammes(from date: Date,
             _ completion: @escaping (Swift.Result<[ChannelProgramme], Error>) -> Void) {
        parse { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let parser):
                do {
                    let programmes = try parser.programme(from: date)
                    completion(.success(programmes))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    private func parse(_ completion: @escaping (Swift.Result<TeleguideInfoParser, Error>) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            let url = Bundle(for: type(of: self)).url(forResource: "epg.xml", withExtension: "gz")!
            let xmlProvider = TeleguideInfoXmlProvider(url: url)
            xmlProvider.info { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let url):
                    let parser = TeleguideInfoParser(url: url)
                    do {
                        _ = try parser.channels()
                        completion(.success(parser))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
}
