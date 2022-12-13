//
//  ChannelsTests.swift
//  ChannelsTests
//
//  Created by Mikhail Demidov on 20.10.2020.
//

import XCTest
@testable import Channels

final class ChannelsTests: XCTestCase {
    
    func testParseM3U8() throws {
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
    
    func testParseM3U() throws {
        let url = Bundle(for: type(of: self)).url(forResource: "plst", withExtension: "m3u")!
        let m3u = M3U(url: url)
        try m3u.parse()
        
        do {
            let expected = M3UItem(
                title: "Paramount Comedy HD",
                url: URL(string: "http://tv.novotelecom.ru/channel/paramount_comedy_hd/592/playlist.m3u8?sid=d2b0c90c6c93af38fec4fa3d898834b1")!,
                group: nil)
            XCTAssertEqual(m3u.items.first, expected)
        }
        
        do {
            let expected = M3UItem(
                title: "ТНТ MUSIC",
                url: URL(string: "http://tv.novotelecom.ru/channel/tnt_music/212/playlist.m3u8?sid=d2b0c90c6c93af38fec4fa3d898834b1")!,
                group: "Музыка")
            XCTAssertEqual(m3u.items.last, expected)
        }
    }
    
    func testParseM3UFree() throws {
        let url = Bundle(for: type(of: self)).url(forResource: "ru-free-pls", withExtension: "m3u")!
        let m3u = M3U(url: url)
        try m3u.parse()
        
        do {
            let expected = M3UItem(
                title: "1HD Music TV",
                url: URL(string: "https://1hdru-hls-otcnet.cdnvideo.ru/onehdmusic/tracks-v1a1/index.m3u8")!,
                group: "")
            XCTAssertEqual(m3u.items.first, expected)
        }
        
        do {
            let expected = M3UItem(
                title: "ЮТВ (Чебоксары)",
                url: URL(string: "http://serv24.vintera.tv:8081/utv/Stream/playlist.m3u8")!,
                group: "Local")
            XCTAssertEqual(m3u.items.last, expected)
        }
    }
    
    func testParseM3UAnother() throws {
        let url = Bundle(for: type(of: self)).url(forResource: "another", withExtension: "m3u")!
        let m3u = M3U(url: url)
        try m3u.parse()
        do {
            let expected = M3UItem(
                title: "1HD Music Television (404p) [Not 24/7]",
                url: URL(string: "https://sc.id-tv.kz/1hd.m3u8")!,
                group: "Music")
            XCTAssertEqual(m3u.items.first, expected)
        }
        
        do {
            let expected = M3UItem(
                title: "Страна FM HD",
                url: URL(string: "http://live.stranafm.cdnvideo.ru/stranafm/stranafm_hd.sdp/playlist.m3u8")!,
                group: "HD")
            XCTAssertEqual(m3u.items.last, expected)
        }
    }
}
