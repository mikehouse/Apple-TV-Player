import Foundation
import SWCompression
import FactoryKit

actor Unarchiver {

    enum UnarchiverError: Error, Equatable {
        case invalidSource
        case unsupportedFormat
        case invalidArchiveEntryPath(String)
        case downloadFailed(Int)
    }

    enum Progress: String, Hashable, CaseIterable, Sendable {
        case start
        case downloading
        case unarchiving
        case complete
    }

    private enum ArchiveFormat {
        case zip
        case tarGz
        case gz
        case tar
    }

    private struct ResolvedArchiveSource {
        let url: URL
        let data: Data
    }

    private struct ArchivedFile {
        let name: String
        let data: Data
    }

    private let fileManager = FileManager.default
    @ObservationIgnored @Injected(\.logger) private var logger

    private let onProgress: @Sendable ([Progress], Progress, isolated Unarchiver) -> Void
    private var progressSteps: [Progress] = []
    private var progress: Progress = .start {
        didSet {
            onProgress(progressSteps, progress, self)
            if progress == .complete {
                progressSteps = []
            }
        }
    }

    init(onProgress: @Sendable @escaping ([Progress], Progress, isolated Unarchiver) -> Void = { _, _, _ in }) {
        self.onProgress = onProgress
    }

    func unarchive(_ source: String) async throws -> [URL] {
        do {
            let url = URL(string: source)
            if url?.isFileURL == true || url?.scheme == nil {
                progressSteps = [.start, .unarchiving, .complete]
            } else {
                progressSteps = Progress.allCases
            }
        }
        progress = .start
        defer {
            progress = .complete
        }
        if progressSteps.contains(.downloading) {
            progress = .downloading
        }
        let resolvedSource = try await resolveArchiveSource(from: source)
        let formats = archiveFormats(for: resolvedSource.url)
        let hasExplicitFormat = hasExplicitFormatHint(for: resolvedSource.url)
        let shouldRethrowImmediately = hasExplicitFormat && formats.count == 1
        var lastError: Error?
        progress = .unarchiving
        for format in formats {
            let extractionDirectory = try makeExtractionDirectory()

            do {
                return try extract(format, from: resolvedSource, into: extractionDirectory)
            } catch {
                lastError = error
                try? fileManager.removeItem(at: extractionDirectory)

                if shouldRethrowImmediately {
                    throw error
                }
            }
        }

        if let lastError, hasExplicitFormat {
            throw lastError
        }

        throw UnarchiverError.unsupportedFormat
    }
}

private extension Unarchiver {

    private func resolveArchiveSource(from source: String) async throws -> ResolvedArchiveSource {
        let measure = try await measureTime {
            return try await _resolveArchiveSource(from: source)
        }
        logger.info("Download archive completed in \(measure.milliseconds) milliseconds", private: source)
        return measure.result
    }

    private func _resolveArchiveSource(from source: String) async throws -> ResolvedArchiveSource {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            throw UnarchiverError.invalidSource
        }

        if let url = URL(string: trimmedSource), url.scheme != nil {
            if url.isFileURL {
                return ResolvedArchiveSource(url: url, data: try Data(contentsOf: url))
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                throw UnarchiverError.downloadFailed(httpResponse.statusCode)
            }

            return ResolvedArchiveSource(url: url, data: data)
        }

        let path = (trimmedSource as NSString).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: path)

        return ResolvedArchiveSource(url: fileURL, data: try Data(contentsOf: fileURL))
    }

    private func archiveFormats(for sourceURL: URL) -> [ArchiveFormat] {
        let path = sourceURL.path.lowercased()

        if path.hasSuffix(".tar.gz") {
            return [.tarGz, .gz]
        }

        if path.hasSuffix(".zip") {
            return [.zip]
        }

        if path.hasSuffix(".tar") {
            return [.tar]
        }

        if path.hasSuffix(".gz") {
            return [.gz]
        }

        return [.zip, .tarGz, .gz, .tar]
    }

    private func hasExplicitFormatHint(for sourceURL: URL) -> Bool {
        let path = sourceURL.path.lowercased()

        return path.hasSuffix(".zip")
            || path.hasSuffix(".tar.gz")
            || path.hasSuffix(".tar")
            || path.hasSuffix(".gz")
    }

    private func makeExtractionDirectory() throws -> URL {
        let directoryURL = fileManager.temporaryDirectory
            .appendingPathComponent("Unarchiver-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return directoryURL
    }

    private func extract(_ format: ArchiveFormat, from source: ResolvedArchiveSource, into extractionDirectory: URL) throws -> [URL] {
        let measure = try measureTime {
            return try _extract(format, from: source, into: extractionDirectory)
        }
        logger.info("Unarchiving completed in \(measure.milliseconds) milliseconds", private: source.url.absoluteString)
        return measure.result
    }

    private func _extract(_ format: ArchiveFormat, from source: ResolvedArchiveSource, into extractionDirectory: URL) throws -> [URL] {
        switch format {
        case .zip:
            return try extractZip(from: source.data, into: extractionDirectory)
        case .tarGz:
            return try extractTarGz(from: source.data, into: extractionDirectory)
        case .gz:
            return try extractGzip(from: source, into: extractionDirectory)
        case .tar:
            return try extractTar(from: source.data, into: extractionDirectory)
        }
    }

    private func extractZip(from archiveData: Data, into extractionDirectory: URL) throws -> [URL] {
        let entries = try ZipContainer.open(container: archiveData)
        let files = entries.compactMap { entry -> ArchivedFile? in
            guard isExtractableEntryType(entry.info.type), let data = entry.data else {
                return nil
            }

            return ArchivedFile(name: entry.info.name, data: data)
        }

        return try write(files, into: extractionDirectory)
    }

    private func extractTar(from archiveData: Data, into extractionDirectory: URL) throws -> [URL] {
        let entries = try TarContainer.open(container: archiveData)
        let files = entries.compactMap { entry -> ArchivedFile? in
            guard isExtractableEntryType(entry.info.type), let data = entry.data else {
                return nil
            }

            return ArchivedFile(name: entry.info.name, data: data)
        }

        return try write(files, into: extractionDirectory)
    }

    private func extractTarGz(from archiveData: Data, into extractionDirectory: URL) throws -> [URL] {
        let members = try GzipArchive.multiUnarchive(archive: archiveData)
        let tarData = members.reduce(into: Data()) { combinedData, member in
            combinedData.append(member.data)
        }

        return try extractTar(from: tarData, into: extractionDirectory)
    }

    private func extractGzip(
        from source: ResolvedArchiveSource,
        into extractionDirectory: URL
    ) throws -> [URL] {
        let members = try GzipArchive.multiUnarchive(archive: source.data)
        let count = members.count
        let files = members.enumerated().map { index, member in
            ArchivedFile(
                name: gzipMemberName(
                    for: member,
                    sourceURL: source.url,
                    index: index,
                    totalCount: count
                ),
                data: member.data
            )
        }

        return try write(files, into: extractionDirectory)
    }

    private func gzipMemberName(
        for member: GzipArchive.Member,
        sourceURL: URL,
        index: Int,
        totalCount: Int
    ) -> String {
        let rawName = member.header.fileName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = fallbackGzipFileName(for: sourceURL)
        let resolvedName = (rawName?.isEmpty == false ? rawName : fallbackName) ?? "archive"

        guard totalCount > 1 else {
            return resolvedName
        }

        let nsName = resolvedName as NSString
        let baseName = nsName.deletingPathExtension
        let pathExtension = nsName.pathExtension
        let numberedBaseName = "\(baseName.isEmpty ? resolvedName : baseName)-\(index + 1)"

        if pathExtension.isEmpty {
            return numberedBaseName
        }

        return "\(numberedBaseName).\(pathExtension)"
    }

    private func fallbackGzipFileName(for sourceURL: URL) -> String? {
        let lastPathComponent = sourceURL.lastPathComponent
        guard !lastPathComponent.isEmpty else {
            return nil
        }

        let lowercasedName = lastPathComponent.lowercased()
        if lowercasedName.hasSuffix(".gz") {
            return String(lastPathComponent.dropLast(3))
        }

        return lastPathComponent
    }

    private func write(_ files: [ArchivedFile], into extractionDirectory: URL) throws -> [URL] {
        var extractedURLs: [URL] = []

        for file in files {
            guard let relativePath = try sanitizedRelativePath(for: file.name) else {
                continue
            }

            let destinationURL = extractionDirectory.appendingPathComponent(relativePath)
            let parentDirectoryURL = destinationURL.deletingLastPathComponent()

            try fileManager.createDirectory(
                at: parentDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try file.data.write(to: destinationURL, options: .atomic)

            extractedURLs.append(destinationURL)
        }

        return extractedURLs
    }

    private func sanitizedRelativePath(for archivedPath: String) throws -> String? {
        let normalizedPath = archivedPath.replacingOccurrences(of: "\\", with: "/")
        let rawComponents = normalizedPath.split(separator: "/", omittingEmptySubsequences: true)

        guard !rawComponents.isEmpty else {
            return nil
        }

        let components = rawComponents.compactMap { component -> String? in
            if component == "." {
                return nil
            }

            return String(component)
        }

        guard !components.isEmpty else {
            return nil
        }

        if components.contains(where: { $0 == ".." }) {
            throw UnarchiverError.invalidArchiveEntryPath(archivedPath)
        }

        if components.contains("__MACOSX") {
            return nil
        }

        if let lastComponent = components.last, lastComponent.hasPrefix("._") {
            return nil
        }

        return components.joined(separator: "/")
    }

    private func isExtractableEntryType(_ type: ContainerEntryType) -> Bool {
        switch type {
        case .regular, .contiguous, .unknown:
            return true
        default:
            return false
        }
    }
}
