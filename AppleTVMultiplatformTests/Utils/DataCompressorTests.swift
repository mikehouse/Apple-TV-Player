import FactoryTesting
import Foundation
import Testing
@testable import Bro_Player

@Suite(.container)
struct DataCompressorTests {

    @Test func compressesStringInput() async throws {
        let compressor = DataCompressor()
        let compressed = try await compressor.compress(Self.fixtureText)

        #expect(!compressed.isEmpty)
        #expect(compressed.count < Self.fixtureData.count)
    }

    @Test func compressesDataInput() async throws {
        let compressor = DataCompressor()
        let compressed = try await compressor.compress(Self.fixtureData)

        #expect(!compressed.isEmpty)
        #expect(compressed.count < Self.fixtureData.count)
    }

    @Test func decompressesToString() async throws {
        let compressor = DataCompressor()
        let compressed = try await compressor.compress(Self.fixtureText)
        let restoredText: String = try await compressor.decompress(compressed)

        #expect(restoredText == Self.fixtureText)
    }

    @Test func decompressesToData() async throws {
        let compressor = DataCompressor()
        let compressed = try await compressor.compress(Self.fixtureData)
        let restoredData: Data = try await compressor.decompress(compressed)

        #expect(restoredData == Self.fixtureData)
    }
}

private extension DataCompressorTests {
    static let fixtureText = """
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. 
    Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. 
    Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    """

    static let fixtureData = Data(fixtureText.utf8)
}
