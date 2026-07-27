import Foundation
import Testing
@testable import Bro_Player

struct PlaylistLogoStorageServiceTests {

    @Test func backsUpLocalFileAndFindsCopiedData() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceData = Data([0x89, 0x50, 0x4E, 0x47])
        let sourceURL = rootURL.appendingPathComponent("playlist-logo.png")
        let backupDirectoryURL = rootURL.appendingPathComponent("Backups", isDirectory: true)
        try sourceData.write(to: sourceURL)

        let service = PlaylistLogoStorageService(directoryURL: backupDirectoryURL)
        let backupURL = try await service.backupLogo(from: sourceURL.absoluteString)

        #expect(backupURL.deletingLastPathComponent() == backupDirectoryURL)
        #expect(backupURL.pathExtension == "png")
        #expect(try Data(contentsOf: backupURL) == sourceData)
        #expect(service.localLogoURL(for: sourceURL.absoluteString) == backupURL)
    }

    @Test func normalizesSourceAndUsesNormalizedFileExtension() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceURL = rootURL.appendingPathComponent("Playlist-Logo.JpG")
        let backupDirectoryURL = rootURL.appendingPathComponent("Backups", isDirectory: true)
        try Data([0xFF, 0xD8, 0xFF]).write(to: sourceURL)

        let source = sourceURL.absoluteString
        let paddedSource = " \n\(source)\t "
        let service = PlaylistLogoStorageService(directoryURL: backupDirectoryURL)

        let backupURL = try await service.backupLogo(from: paddedSource)

        #expect(backupURL.pathExtension == "jpg")
        #expect(service.localLogoURL(for: source) == backupURL)
        #expect(service.localLogoURL(for: paddedSource) == backupURL)
        let repeatedBackupURL = try await service.backupLogo(from: source)
        #expect(repeatedBackupURL == backupURL)
    }

    @Test func usesImageExtensionWhenSourceHasNoSafeExtension() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceURL = rootURL.appendingPathComponent("playlist-logo")
        let backupDirectoryURL = rootURL.appendingPathComponent("Backups", isDirectory: true)
        try Data([0x01]).write(to: sourceURL)

        let service = PlaylistLogoStorageService(directoryURL: backupDirectoryURL)
        let backupURL = try await service.backupLogo(from: sourceURL.absoluteString)

        #expect(backupURL.pathExtension == "img")
        #expect(service.localLogoURL(for: sourceURL.absoluteString) == backupURL)
    }

    @Test func replacesExistingBackupForSameSource() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let sourceURL = rootURL.appendingPathComponent("playlist-logo.webp")
        let backupDirectoryURL = rootURL.appendingPathComponent("Backups", isDirectory: true)
        let originalData = Data([0x01, 0x02])
        let replacementData = Data([0x03, 0x04, 0x05])
        try originalData.write(to: sourceURL)

        let service = PlaylistLogoStorageService(directoryURL: backupDirectoryURL)
        let firstBackupURL = try await service.backupLogo(from: sourceURL.absoluteString)
        try replacementData.write(to: sourceURL, options: .atomic)
        let secondBackupURL = try await service.backupLogo(from: sourceURL.absoluteString)

        #expect(firstBackupURL == secondBackupURL)
        #expect(try Data(contentsOf: secondBackupURL) == replacementData)
    }

    @Test func rejectsBlankSource() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let service = PlaylistLogoStorageService(directoryURL: rootURL)

        do {
            _ = try await service.backupLogo(from: " \n\t ")
            Issue.record("Expected a blank source to be rejected.")
        } catch PlaylistLogoStorageService.Error.invalidSource {
            #expect(service.localLogoURL(for: " \n\t ") == nil)
        } catch {
            Issue.record("Expected invalidSource, got \(error).")
        }
    }

    @Test func reportsUnavailableLocalFile() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let missingSourceURL = rootURL.appendingPathComponent("missing-logo.png")
        let service = PlaylistLogoStorageService(
            directoryURL: rootURL.appendingPathComponent("Backups", isDirectory: true)
        )

        do {
            _ = try await service.backupLogo(from: missingSourceURL.absoluteString)
            Issue.record("Expected a missing local file to be rejected.")
        } catch PlaylistLogoStorageService.Error.localFileUnavailable {
            #expect(service.localLogoURL(for: missingSourceURL.absoluteString) == nil)
        } catch {
            Issue.record("Expected localFileUnavailable, got \(error).")
        }
    }

    @Test func downloadsRemoteLogoAndStoresItLocally() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let session = makeStubbedURLSession()
        defer { session.invalidateAndCancel() }
        let service = PlaylistLogoStorageService(
            directoryURL: rootURL,
            urlSession: session
        )
        let source = "https://playlist-logo.test/success/brand.PNG?revision=2"

        let backupURL = try await service.backupLogo(from: source)

        #expect(backupURL.pathExtension == "png")
        #expect(try Data(contentsOf: backupURL) == PlaylistLogoURLProtocol.remoteImageData)
        #expect(service.localLogoURL(for: source) == backupURL)
    }

    @Test func rejectsRemoteNonSuccessfulHTTPResponse() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let session = makeStubbedURLSession()
        defer { session.invalidateAndCancel() }
        let service = PlaylistLogoStorageService(
            directoryURL: rootURL,
            urlSession: session
        )
        let source = "https://playlist-logo.test/unavailable/logo.png"

        do {
            _ = try await service.backupLogo(from: source)
            Issue.record("Expected an unsuccessful HTTP response to be rejected.")
        } catch let error as PlaylistLogoStorageService.Error {
            switch error {
            case .downloadFailed(let statusCode):
                #expect(statusCode == 503)
            default:
                Issue.record("Expected downloadFailed, got \(error).")
            }
        } catch {
            Issue.record("Expected PlaylistLogoStorageService.Error, got \(error).")
        }

        #expect(service.localLogoURL(for: source) == nil)
    }
}

private extension PlaylistLogoStorageServiceTests {

    func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directoryURL
    }

    func makeStubbedURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PlaylistLogoURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private nonisolated final class PlaylistLogoURLProtocol: URLProtocol, @unchecked Sendable {

    static let remoteImageData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "playlist-logo.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let isSuccessful = url.path.hasPrefix("/success/")
        let statusCode = isSuccessful ? 200 : 503
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/png"]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.remoteImageData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
