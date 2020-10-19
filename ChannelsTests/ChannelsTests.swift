//
//  ChannelsTests.swift
//  ChannelsTests
//
//  Created by Mikhail Demidov on 20.10.2020.
//

import XCTest
@testable import Channels

final class ChannelsTests: XCTestCase {
    
    func testParseM3U() throws {
        let url = Bundle(for: type(of: self)).url(forResource: "android", withExtension: "m3u8")!
        let m3u = M3U(url: url)
        try m3u.parse()
        
        do {
            let expected = M3UItem(
                title: "Первый канал",
                url: URL(string: "http://94.hlstv.nsk.211.ru/239.211.0.1.m3u8")!,
                group: "Эфирные")
            XCTAssertEqual(m3u.items.first, expected)
        }
        
        do {
            let expected = M3UItem(
                title: "МИР 24 HD",
                url: URL(string: "http://94.hlstv.nsk.211.ru/239.211.200.40.m3u8")!,
                group: "HD каналы")
            XCTAssertEqual(m3u.items.last, expected)
        }
    }
}
