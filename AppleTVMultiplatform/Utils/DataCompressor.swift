import Foundation

actor DataCompressor {

    enum Error: Swift.Error, Equatable {
        case invalidUTF8Data
    }

    private static let algorithm: NSData.CompressionAlgorithm = .zlib

    func compress(_ string: String) throws -> Data {
        try compress(Data(string.utf8))
    }

    func compress(_ data: Data) throws -> Data {
        try (data as NSData).compressed(using: Self.algorithm) as Data
    }

    func decompress(_ data: Data) throws -> Data {
        try decompressedData(from: data)
    }

    func decompress(_ data: Data) throws -> String {
        guard let string = try String(data: decompress(data), encoding: .utf8) else {
            throw DataCompressor.Error.invalidUTF8Data
        }
        return string
    }

    private func decompressedData(from data: Data) throws -> Data {
        try (data as NSData).decompressed(using: Self.algorithm) as Data
    }
}
