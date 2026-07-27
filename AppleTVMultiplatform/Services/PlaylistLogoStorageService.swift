import CryptoKit
import FactoryKit
import Foundation

protocol PlaylistLogoStorageServiceInterface: AnyObject, Sendable {
    func backupLogo(from source: String) async throws -> URL
    nonisolated func localLogoURL(for source: String) -> URL?
}

actor PlaylistLogoStorageService: PlaylistLogoStorageServiceInterface {

    @ObservationIgnored @Injected(\.logger) private var logger

    enum Error: Swift.Error, LocalizedError {
        case invalidSource
        case downloadFailed(Int)
        case localFileUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidSource:
                return "The logo image URL is invalid."
            case .downloadFailed(let statusCode):
                return "Failed to download the logo image (HTTP \(statusCode))."
            case .localFileUnavailable:
                return "The selected logo image could not be read."
            }
        }
    }

    private let directoryURL: URL
    private let urlSession: URLSession

    init(directoryURL: URL? = nil, urlSession: URLSession = .shared) {
        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let appDirectoryName = Bundle.main.bundleIdentifier ?? "AppleTVMultiplatform"
        self.directoryURL = directoryURL
            ?? applicationSupportURL
                .appendingPathComponent(appDirectoryName, isDirectory: true)
                .appendingPathComponent("PlaylistLogoBackups", isDirectory: true)
        self.urlSession = urlSession
    }

    func backupLogo(from source: String) async throws -> URL {
        try Task.checkCancellation()
        guard
            let normalizedSource = Self.normalized(source),
            let sourceURL = Self.resolvedURL(from: normalizedSource),
            let backupURL = backupURL(for: normalizedSource)
        else {
            throw Error.invalidSource
        }

        let data: Data
        if sourceURL.isFileURL {
            do {
                data = try Data(contentsOf: sourceURL)
            } catch {
                throw Error.localFileUnavailable
            }
        } else {
            var request = URLRequest(url: sourceURL)
            request.timeoutInterval = 15
            let (downloadedData, response) = try await urlSession.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200 ... 299).contains(httpResponse.statusCode) {
                throw Error.downloadFailed(httpResponse.statusCode)
            }
            data = downloadedData
        }

        try Task.checkCancellation()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try Task.checkCancellation()
        try data.write(to: backupURL, options: .atomic)
        return backupURL
    }

    nonisolated func localLogoURL(for source: String) -> URL? {
        guard
            let backupURL = backupURL(for: source),
            FileManager.default.fileExists(atPath: backupURL.path)
        else {
            return nil
        }
        return backupURL
    }
}

private extension PlaylistLogoStorageService {

    nonisolated func backupURL(for source: String) -> URL? {
        guard let normalizedSource = Self.normalized(source) else {
            return nil
        }

        let digest = SHA256.hash(data: Data(normalizedSource.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let pathExtension = Self.safePathExtension(for: normalizedSource)

        return directoryURL
            .appendingPathComponent(digest, isDirectory: false)
            .appendingPathExtension(pathExtension)
    }

    nonisolated static func normalized(_ value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    nonisolated static func resolvedURL(from source: String) -> URL? {
        if let url = URL(string: source), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: (source as NSString).expandingTildeInPath)
    }

    nonisolated static func safePathExtension(for source: String) -> String {
        guard
            let pathExtension = resolvedURL(from: source)?.pathExtension.lowercased(),
            !pathExtension.isEmpty,
            pathExtension.count <= 16,
            pathExtension.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
        else {
            return "img"
        }
        return pathExtension
    }
}

extension FactoryKit.Container {

    @MainActor
    var playlistLogoStorageService: Factory<PlaylistLogoStorageServiceInterface> {
        self { PlaylistLogoStorageService() }.singleton
    }
}
