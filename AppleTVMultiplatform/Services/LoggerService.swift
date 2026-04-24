import Foundation
import FactoryKit
import os
import OSLog

@Observable
nonisolated final class LoggerService {

    private let logger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "iptv-app")

    func info(
        _ message: String,
        `private`: String = "",
        file: String = #filePath,
        line: Int = #line
    ) {
        let link = fileLink(file: file, line: line)
        logger.info("\(link, privacy: .public) \(message, privacy: .public) \(`private`, privacy: .private)")
    }

    func info(
        _ message: String,
        `private`: CustomStringConvertible,
        file: String = #filePath,
        line: Int = #line
    ) {
        self.info(message, private: String(describing: `private`), file: file, line: line)
    }

    func debug(
        _ message: String,
        `private`: String = "",
        file: String = #filePath,
        line: Int = #line
    ) {
        let link = fileLink(file: file, line: line)
        logger.info("\(link, privacy: .public) \(message, privacy: .public) \(`private`, privacy: .private)")
    }

    func error(
        _ message: String,
        `private`: String = "",
        file: String = #filePath,
        line: Int = #line
    ) {
        let link = fileLink(file: file, line: line)
        logger.error("\(link, privacy: .public) \(message, privacy: .public) \(`private`, privacy: .private)")
    }

    func error(
        _ error: Swift.Error,
        `private`: String = "",
        file: String = #filePath,
        line: Int = #line
    ) {
        self.error("\(error)", private: `private`, file: file, line: line)
    }

    func error(
        _ error: Swift.Error,
        `private`: CustomStringConvertible,
        file: String = #filePath,
        line: Int = #line
    ) {
        self.error(error, private: String(describing: `private`), file: file, line: line)
    }

    func errorFirebase(
        _ error: Swift.Error,
        `private`: String = "",
        file: String = #filePath,
        line: Int = #line
    ) {
        //
    }

    // MARK: - Private

    private func fileLink(file: String, line: Int) -> String {
        "\(URL(fileURLWithPath: file, isDirectory: false).lastPathComponent):\(line)"
    }
}

extension FactoryKit.Container {

    nonisolated var logger: Factory<LoggerService> {
        self { LoggerService() }.singleton
    }
}