
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import Foundation
import XCTest
import Testing
import SnapshotTesting

@MainActor
struct SnapshotUtils {
    
    let env: MockAppEnv
    let apiClient: MockApiClient
    let name: String
    
#if !os(macOS)
    func assertSnapshot(
        named: String, app: XCUIApplication, localized: Bool, precision: Float = 0.9994,
        fileID: StaticString = #fileID, file filePath: StaticString = #filePath,
        line: UInt = #line, column: UInt = #column
    ) {
        let image: UIImage
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssert(XCUIDevice.shared.orientation == .landscapeLeft)
            image = flattenOrientation(XCUIScreen.main.screenshot().image)
        } else {
            image = app.screenshot().image
        }
#else
        image = app.screenshot().image
#endif
        var snapshotDirectory = URL(fileURLWithPath: String(describing: filePath))
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__", isDirectory: true)
            .appendingPathComponent(URL(fileURLWithPath: String(describing: filePath)).deletingPathExtension().lastPathComponent, isDirectory: true)
    #if os(iOS)
        snapshotDirectory = snapshotDirectory.appendingPathComponent("iOS", isDirectory: true)
    #else
        snapshotDirectory = snapshotDirectory.appendingPathComponent("tvOS", isDirectory: true)
    #endif
        if localized {
            snapshotDirectory = snapshotDirectory.appendingPathComponent(env.langAndLocale, isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        
        guard let message = SnapshotTesting.verifySnapshot(
            of: image, as: .image(precision: precision),
            named: named,
            record: .failed,
            snapshotDirectory: snapshotDirectory.path,
            fileID: fileID,
            file: filePath,
            testName: name,
            line: line, column: column
        ) else {
            return
        }
        if Test.current != nil {
        Issue.record(
          Comment(rawValue: message),
          sourceLocation: SourceLocation(
            fileID: fileID.description,
            filePath: filePath.description,
            line: Int(line),
            column: Int(column)
          )
        )
        } else {
          XCTFail(message, file: filePath, line: line)
        }
    }
#endif
#if os(macOS)
    func assertSnapshot(
        named: String, app: XCUIApplication, localized: Bool, precision: Float = 0.9994, rerun: Bool = false,
        fileID: StaticString = #fileID, file filePath: StaticString = #filePath,
        line: UInt = #line, column: UInt = #column
    ) async throws {
        let snapshotDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("macOS-Snapshots", isDirectory: true)
        // Delete to trigger error from where we will extract snapshot name.
        if !rerun {
            try? FileManager.default.removeItem(at: snapshotDirectory)
        }
        try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
        
        let image: NSImage = app.windows.element(boundBy: 0).screenshot().image
        guard let message = SnapshotTesting.verifySnapshot(
            of: image, as: .image(precision: precision),
            named: named,
            record: .failed,
            snapshotDirectory: snapshotDirectory.path,
            fileID: fileID,
            file: filePath,
            testName: name,
            line: line, column: column
        ) else {
            return
        }
        
        var gitSnapshotsDir = URL(fileURLWithPath: String(describing: filePath))
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__", isDirectory: true)
            .appendingPathComponent(URL(fileURLWithPath: String(describing: filePath)).deletingPathExtension().lastPathComponent, isDirectory: true)
            .appendingPathComponent("macOS", isDirectory: true)
        if localized {
            gitSnapshotsDir = gitSnapshotsDir.appendingPathComponent(env.langAndLocale, isDirectory: true)
        }
        
        switch message {
        case let message where message.contains("No reference was found on disk."):
            guard let start = message.range(of: #"open ""#),
                let end = message[start.upperBound...].firstIndex(of: "\""),
                let snapshotPath = URL(string: String(message[start.upperBound..<end])) else {
                return XCTFail("Could not parse snapshot file path from message:\n\(message)\n", file: filePath, line: line)
            }
            do {
                // Now we know snapshot path and name. Copy from .git the snapshot to re-run one more time.
                try await apiClient.copySnapshot(
                    from: gitSnapshotsDir.appendingPathComponent(snapshotPath.lastPathComponent, isDirectory: false).path,
                    to: snapshotPath.deletingLastPathComponent().path
                )
                return try await self.assertSnapshot(
                    named: named, app: app, localized: localized, precision: precision,
                    rerun: true, fileID: fileID, file: filePath, line: line, column: column
                )
            } catch {
                // There is no .git version yet, copy new generated there.
                try await apiClient.copySnapshot(from: snapshotPath.path, to: gitSnapshotsDir.path)
                return XCTFail("New snapshot copied to .git, rerun test.", file: filePath, line: line)
            }
        case let message where message.contains("does not match reference"):
            // Here when new generated snapshot does match with .git version.
            // Copy new one to .git to compare visually.
            guard let regex = try? NSRegularExpression(pattern: #"(?m)^@\+\s*$\R^"(file://[^"]+)""#),
                  let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
                  let range = Range(match.range(at: 1), in: message),
                  let snapshotPath = URL(string: "file://\(String(message[range]))") else {
                return XCTFail("Could not parse snapshot file path from message:\n\(message)\n", file: filePath, line: line)
            }
            try await apiClient.copySnapshot(from: snapshotPath.path, to: gitSnapshotsDir.path)
        default:
            break
        }
        
        if Test.current != nil {
        Issue.record(
          Comment(rawValue: message),
          sourceLocation: SourceLocation(
            fileID: fileID.description,
            filePath: filePath.description,
            line: Int(line),
            column: Int(column)
          )
        )
        } else {
          XCTFail(message, file: filePath, line: line)
        }
    }
#endif

#if os(iOS)
    private func flattenOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
        }
    }
#endif
}
