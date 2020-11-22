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
        let pls = Bundle.main.url(forResource: "plst", withExtension: "m3u")!
        let plsUncompressed = try Data(contentsOf: pls)
        let plsCompressed = try piedPiper.compress(data: plsUncompressed)
        let plsDecompressed = try piedPiper.decompress(data: plsCompressed)
        
        XCTAssertTrue(plsCompressed.count < plsUncompressed.count / 2, "Data compressed more than 2 times.")
        XCTAssertTrue(plsDecompressed.count == plsUncompressed.count, "Data compression/decompression no data lose.")
    }
}
