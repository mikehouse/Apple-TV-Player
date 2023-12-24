//
//  Apple_TV_PlayerTests.swift
//  Apple-TV-PlayerTests
//
//  Created by Mikhail Demidov on 22.11.2020.
//

import XCTest
@testable import Apple_TV_Player

final class Apple_TV_PlayerTests: XCTestCase {
    
    func testExample() throws {
        let piedPiper = PiedPiper()
        let pls = Bundle(for: Apple_TV_PlayerTests.self).url(forResource: "plst", withExtension: "m3u")!
        let plsUncompressed = try Data(contentsOf: pls)
        let plsCompressed = try piedPiper.compress(data: plsUncompressed)
        let plsDecompressed = try piedPiper.decompress(data: plsCompressed)
        
        XCTAssertTrue(plsCompressed.count < plsUncompressed.count / 2, "Data compressed more than 2 times.")
        XCTAssertTrue(plsDecompressed.count == plsUncompressed.count, "Data compression/decompression no data lose.")
    }

    func testPinCode() throws {
        UserDefaults().removePersistentDomain(forName: "\(#function)")
        let userDefaults = UserDefaults.init(suiteName: "\(#function)")!
        let fs = FileSystemManager(storage: userDefaults)
        let playlist = "my playlist"
        let pin = "12345"
        XCTAssertNil(fs.pin(playlist: playlist))
        let pls = Bundle(for: Apple_TV_PlayerTests.self).url(forResource: "plst", withExtension: "m3u")!
        try fs.download(file: pls, playlist: playlist, pin: pin)
        XCTAssertTrue(fs.verify(pin: pin, playlist: playlist))
        XCTAssertFalse(fs.verify(pin: "wrong", playlist: playlist))
        try XCTAssertThrowsError(fs.removePin(playlist: playlist, pin: "wrong"))
        XCTAssertNotNil(fs.pin(playlist: playlist))
        try fs.removePin(playlist: playlist, pin: pin)
        XCTAssertNil(fs.pin(playlist: playlist))
    }
}
