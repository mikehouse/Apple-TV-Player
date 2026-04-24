import FactoryTesting
import Foundation
import Testing
import os
@testable import Bro_Player

@Suite(.container)
struct UnarchiverTests {

    @Test func unarchivesGzipArchiveToTemporaryDirectory() async throws {
        let archivePath = try resourceURL(named: "test.xml.gz").path
        let receiveSteps = OSAllocatedUnfairLock(initialState: [Unarchiver.Progress]())
        let foundSteps = OSAllocatedUnfairLock(initialState: [Unarchiver.Progress]())
        let extractedURLs = try await Unarchiver { steps, step, _ in
            receiveSteps.withLock { $0 = steps }
            foundSteps.withLock({ $0.append(step) })
        }.unarchive(archivePath)
        defer { cleanupExtraction(at: extractedURLs) }

        #expect(extractedURLs.count == 1)

        let extractedURL = try #require(extractedURLs.first)
        // This gzip resource doesn't store an original filename in its header, so the helper derives it from the archive name.
        #expect(extractedURL.lastPathComponent == "test.xml")

        let content = try String(contentsOf: extractedURL, encoding: .utf8)
        #expect(content.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(content.contains("<tv "))
        
        let expectedSteps: [Unarchiver.Progress] = [.start, .unarchiving, .complete]
        receiveSteps.withLock({
            #expect(expectedSteps == $0)
        })
        foundSteps.withLock({
            #expect(expectedSteps == $0)
        })
    }

    @Test func unarchivesZipArchiveToTemporaryDirectory() async throws {
        let archivePath = try resourceURL(named: "test.xml.zip").path
        let extractedURLs = try await Unarchiver().unarchive(archivePath)
        defer { cleanupExtraction(at: extractedURLs) }

        #expect(extractedURLs.count == 1)

        let extractedURL = try #require(extractedURLs.first)
        #expect(extractedURL.lastPathComponent == "us.xml")

        let content = try String(contentsOf: extractedURL, encoding: .utf8)
        #expect(content.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(content.contains("<tv "))
    }
    
    @Test func unarchivesNotExistedRemoteArchive() async throws {
        let archivePath = "https://google.com/archive.zip"
        let receiveSteps = OSAllocatedUnfairLock(initialState: [Unarchiver.Progress]())
        let foundSteps = OSAllocatedUnfairLock(initialState: [Unarchiver.Progress]())
        await #expect(throws: Error.self) {
            _ = try await Unarchiver { steps, step, _ in
                receiveSteps.withLock { $0 = steps }
                foundSteps.withLock({ $0.append(step) })
            }.unarchive(archivePath)
        }
        try await Task.sleep(for: .seconds(0.01))
        receiveSteps.withLock({
            #expect([.start, .downloading, .unarchiving, .complete] == $0)
        })
        foundSteps.withLock({
            #expect([.start, .downloading, .complete] == $0)
        })
    }
}

private extension UnarchiverTests {

    func resourceURL(named resourceName: String) throws -> URL {
        let bundle = Bundle(for: BundleLocator.self)

        if let resourceURL = bundle.url(forResource: resourceName, withExtension: nil) {
            return resourceURL
        }

        if let resourceURL = bundle.url(
            forResource: (resourceName as NSString).deletingPathExtension,
            withExtension: (resourceName as NSString).pathExtension,
            subdirectory: "Resources"
        ) {
            return resourceURL
        }

        throw TestError.missingResource(resourceName)
    }

    func cleanupExtraction(at extractedURLs: [URL]) {
        let roots = Set(extractedURLs.compactMap(extractionRoot(for:)))

        for root in roots {
            try? FileManager.default.removeItem(at: root)
        }
    }

    func extractionRoot(for extractedURL: URL) -> URL? {
        var currentURL = extractedURL

        while currentURL.path != "/" {
            if currentURL.lastPathComponent.hasPrefix("Unarchiver-") {
                return currentURL
            }

            currentURL.deleteLastPathComponent()
        }

        return nil
    }
}

private final class BundleLocator: NSObject {}

private enum TestError: Error {
    case missingResource(String)
}
