import CryptoKit
import FactoryKit
import Foundation

protocol PlaylistServiceInterface: AnyObject, Sendable {
    typealias ProgressHandler = @Sendable ([PlaylistService.Progress], PlaylistService.Progress) -> Void
    func playlists(for content: PlaylistItem.Content, reloadProgramGuide: Bool, progress: @escaping ProgressHandler) async throws -> [PlaylistParser.Playlist]
    func playlists(for content: PlaylistItem.Content, reloadPlaylist: Bool, progress: @escaping ProgressHandler) async throws -> [PlaylistParser.Playlist]
    func programGuide(for content: PlaylistItem.Content, stream: PlaylistParser.Stream) async -> ProgramGuide?
    func programGuides(for content: PlaylistItem.Content, since: Date) async -> [ProgramGuide]
    func clearCache(for content: PlaylistItem.Content) async
}

actor PlaylistService: PlaylistServiceInterface {

    enum Progress: String, Hashable, CaseIterable, Sendable {
        case start
        case downloadingProgramGuide
        case downloadingLogos
        case downloadingPlaylist
        case unarchivingProgramGuide
        case unarchivingLogos
        case parsingProgramGuide
        case parsingPlaylist
        case complete
        
        var title: String {
            switch self {
            case .start:
                return String(localized: "Starting")
            case .downloadingProgramGuide:
                return String(localized: "Download Program Guide")
            case .downloadingLogos:
                return String(localized: "Download Icons")
            case .downloadingPlaylist:
                return String(localized: "Download Playlist")
            case .unarchivingProgramGuide:
                return String(localized: "Extracting Program Guide")
            case .unarchivingLogos:
                return String(localized: "Extracting Icons")
            case .parsingProgramGuide:
                return String(localized: "Reading Program Guide")
            case .parsingPlaylist:
                return String(localized: "Reading Playlist")
            case .complete:
                return String(localized: "Complete")
            }
        }
    }

    private enum ProgressInitiator {
        case programGuide
        case logos
    }

    private struct CacheKey: Hashable, Sendable {
        let name: String
        let date: Date
    }

    private struct CacheEntry {
        let playlists: [PlaylistParser.Playlist]
        let programGuides: [ProgramGuide]
        let guideCacheURLs: Set<URL>
        let imageCacheURLs: Set<URL>
    }

    private let cacheDirectoryURL: URL
    private var cache: [CacheKey: CacheEntry] = [:]
    private let onProgress: ProgressHandler
    @ObservationIgnored @Injected(\.logger) private var logger

    init(
        cacheDirectoryURL: URL? = nil,
        onProgress: @escaping ProgressHandler = { _, _ in }
    ) {
        let fileManager = FileManager.default
        self.cacheDirectoryURL = cacheDirectoryURL
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("PlaylistService", isDirectory: true)
        self.onProgress = onProgress
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadProgramGuide: Bool,
        progress: @escaping ProgressHandler = { _, _ in }
    ) async throws -> [PlaylistParser.Playlist] {
        try await playlists(for: content, reloadProgramGuide: reloadProgramGuide, reloadPlaylist: false, progress: progress)
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadPlaylist: Bool,
        progress: @escaping ProgressHandler = { _, _ in }
    ) async throws -> [PlaylistParser.Playlist] {
        try await playlists(for: content, reloadProgramGuide: false, reloadPlaylist: reloadPlaylist, progress: progress)
    }

    func programGuide(
        for content: PlaylistItem.Content,
        stream: PlaylistParser.Stream
    ) async -> ProgramGuide? {
        let candidateNames = streamCandidateNames(for: stream)
        guard !candidateNames.isEmpty else {
            return nil
        }

        let guides: [ProgramGuide]
        if let cacheEntry = cache[cacheKey(for: content)] {
            guides = cacheEntry.programGuides
        } else {
            _ = try? await playlists(for: content, reloadPlaylist: false)
            guides = cache[cacheKey(for: content)]?.programGuides ?? []
        }

        let exact = guides.first { guide in
            guard let displayName = normalized(guide.channel.displayName) else {
                return false
            }

            return candidateNames.contains(displayName)
        }
        if let exact {
            return exact
        }
        return guides.first { guide in
            guard let displayName = normalized(guide.channel.displayName) else {
                return false
            }
            // Cases like "Channel Name" vs "Channel Name HD" or vise versa.
            return candidateNames.contains(where: { $0.hasPrefix(displayName) })
                || candidateNames.contains(where: { displayName.hasPrefix($0) })
        }
    }

    func programGuides(for content: PlaylistItem.Content, since: Date) async -> [ProgramGuide] {
        let cacheKey = cacheKey(for: content)
        guard let cached = cache[cacheKey] else {
            return []
        }
        return cached.programGuides.filter { !$0.programs.filter({ $0.start > since }).isEmpty }
    }

    func clearCache(for content: PlaylistItem.Content) async {
        let removedCacheEntry = cache.removeValue(forKey: cacheKey(for: content))
        var cachedGuideCacheURLs = removedCacheEntry?.guideCacheURLs ?? Set<URL>()
        var cachedImageCacheURLs = removedCacheEntry?.imageCacheURLs ?? Set<URL>()

        if ((!content.isStoredInMemoryOnly && cachedGuideCacheURLs.isEmpty) || cachedImageCacheURLs.isEmpty),
           let playlists = try? await parsePlaylists(from: content.data, progress: { _, _ in }) {
            if !content.isStoredInMemoryOnly, cachedGuideCacheURLs.isEmpty {
                cachedGuideCacheURLs = resolvedGuideCacheURLs(for: playlists)
            }

            if cachedImageCacheURLs.isEmpty {
                cachedImageCacheURLs = resolvedImageCacheURLs(for: playlists)
            }
        }

        for url in cachedGuideCacheURLs {
            logger.info("Deleting program guide cache", private: url)
            try? FileManager.default.removeItem(at: url)
        }

        for url in cachedImageCacheURLs {
            logger.info("Deleting logos image cache", private: url)
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func playlists(
        for content: PlaylistItem.Content,
        reloadProgramGuide: Bool,
        reloadPlaylist: Bool,
        progress: @escaping ProgressHandler = { _, _ in }
    ) async throws -> [PlaylistParser.Playlist] {
        let cacheKey = cacheKey(for: content)
        if let cacheEntry = cache[cacheKey], !reloadProgramGuide, !reloadPlaylist {
            return cacheEntry.playlists
        }

        let playlists: [PlaylistParser.Playlist]
        if !reloadPlaylist, let cachedPlaylists = cache[cacheKey]?.playlists {
            playlists = cachedPlaylists
        } else {
            await logger.info("Parse playlist data", private: content.id.description)
            playlists = try await parsePlaylists(from: content.data, progress: progress)
        }
        await logger.info("Load program guide", private: content.id.description)
        let (programGuides, guideCacheURLs) = try await loadProgramGuides(
            for: playlists,
            reload: reloadProgramGuide || reloadPlaylist,
            storeOnDisk: !content.isStoredInMemoryOnly,
            progress: progress
        )
        await logger.info("Load streams logos", private: content.id.description)
        let (resolvedPlaylists, imageCacheURLs) = await resolvePlaylistImages(
            for: playlists,
            reload: reloadPlaylist,
            progress: progress
        )

        cache[cacheKey] = CacheEntry(
            playlists: resolvedPlaylists,
            programGuides: programGuides,
            guideCacheURLs: guideCacheURLs,
            imageCacheURLs: imageCacheURLs
        )
        return resolvedPlaylists
    }
}

private extension PlaylistService {

    func parsePlaylists(from data: Data, progress: ProgressHandler) async throws -> [PlaylistParser.Playlist] {
        let progressList: [Progress] = [.start, .parsingPlaylist, .complete]
        progress(progressList, .start)
        progress(progressList, .parsingPlaylist)
        let playlist = try await PlaylistParser(data: data).parse()
        progress(progressList, .complete)
        return playlist
    }

    func loadProgramGuides(
        for playlists: [PlaylistParser.Playlist],
        reload: Bool,
        storeOnDisk: Bool,
        progress: @escaping ProgressHandler
    ) async throws -> (guides: [ProgramGuide], guideCacheURLs: Set<URL>) {
        var guides: [ProgramGuide] = []
        var guideCacheURLs = Set<URL>()
        var processedSources = Set<String>()

        if storeOnDisk {
            try ensureCacheDirectoryExists()
        }

        for playlist in playlists {
            guard
                let source = programGuideSource(for: playlist),
                processedSources.insert(source).inserted,
                let sourceURL = resolvedURL(from: source)
            else {
                continue
            }

            let parsedGuides: [ProgramGuide]
            if storeOnDisk {
                let guideCacheURL = guideCacheURL(for: source)
                guideCacheURLs.insert(guideCacheURL)
                do {
                    parsedGuides = try await loadProgramGuides(
                        from: sourceURL,
                        cacheURL: guideCacheURL,
                        reload: reload,
                        progress: progress
                    )
                } catch {
                    logger.error(error)
                    parsedGuides = []
                }
            } else {
                do {
                    parsedGuides = try await loadProgramGuidesInMemory(from: sourceURL, progress: progress)
                } catch {
                    logger.error(error)
                    parsedGuides = []
                }
            }
            guides.append(contentsOf: parsedGuides)
        }

        return (guides, guideCacheURLs)
    }

    func resolvePlaylistImages(
        for playlists: [PlaylistParser.Playlist],
        reload: Bool,
        progress: @escaping ProgressHandler
    ) async -> (playlists: [PlaylistParser.Playlist], imageCacheURLs: Set<URL>) {
        var resolvedPlaylists: [PlaylistParser.Playlist] = []
        var imageCacheURLs = Set<URL>()
        var resolvedImageRoots: [String: URL] = [:]
        var unavailableSources = Set<String>()
        var didEnsureCacheDirectory = false
        var canUseCacheDirectory = true

        for playlist in playlists {
            guard let source = normalized(playlist.imageURL) else {
                resolvedPlaylists.append(playlist)
                continue
            }

            let imageCacheURL = imageCacheURL(for: source)
            imageCacheURLs.insert(imageCacheURL)

            let imageRootURL: URL?
            if let cachedRootURL = resolvedImageRoots[source] {
                imageRootURL = cachedRootURL
            } else if unavailableSources.contains(source) {
                imageRootURL = nil
            } else {
                if !didEnsureCacheDirectory {
                    do {
                        try ensureCacheDirectoryExists()
                    } catch {
                        logger.error(error)
                        canUseCacheDirectory = false
                    }
                    didEnsureCacheDirectory = true
                }

                if canUseCacheDirectory,
                   let preparedImageCacheURL = await preparedImageCacheURL(
                        for: source,
                        cacheURL: imageCacheURL,
                        reload: reload,
                        progress: progress
                   ) {
                    resolvedImageRoots[source] = preparedImageCacheURL
                    imageRootURL = preparedImageCacheURL
                } else {
                    unavailableSources.insert(source)
                    imageRootURL = nil
                }
            }

            guard let imageRootURL else {
                resolvedPlaylists.append(playlist)
                continue
            }

            let resolvedStreams = playlist.streams.map {
                resolvedStreamLogo(for: $0, imageRootURL: imageRootURL)
            }

            resolvedPlaylists.append(
                PlaylistParser.Playlist(
                    tvgURL: playlist.tvgURL,
                    imageURL: playlist.imageURL,
                    xTvgURL: playlist.xTvgURL,
                    tvgLogo: playlist.tvgLogo,
                    streams: resolvedStreams
                )
            )
        }

        return (resolvedPlaylists, imageCacheURLs)
    }

    func loadProgramGuidesInMemory(from sourceURL: URL, progress: @escaping ProgressHandler) async throws -> [ProgramGuide] {
        if sourceURL.pathExtension.lowercased() == "xml" {
            return try await programGuideParser(progress: progress).parse(xmlURL: sourceURL)
        }

        do {
            return try await programGuideParser(progress: progress).parse(archiveURL: sourceURL)
        } catch {
            logger.error(error)
            return try await programGuideParser(progress: progress).parse(xmlURL: sourceURL)
        }
    }

    func loadProgramGuides(
        from sourceURL: URL,
        cacheURL: URL,
        reload: Bool,
        progress: @escaping ProgressHandler
    ) async throws -> [ProgramGuide] {
        if !reload, FileManager.default.fileExists(atPath: cacheURL.path) {
            do {
                return try await programGuideParser(progress: progress).parse(xmlURL: cacheURL)
            } catch {
                logger.error(error)
                try? FileManager.default.removeItem(at: cacheURL)
            }
        }

        try await refreshProgramGuideCache(
            from: sourceURL,
            cacheURL: cacheURL,
            progress: progress
        )
        return try await programGuideParser(progress: progress).parse(xmlURL: cacheURL)
    }

    func programGuideParser(progress: @escaping ProgressHandler) -> ProgramGuideParser {
        ProgramGuideParser(onProgress: { steps, step, _ in
            func convert(_ progress: ProgramGuideParser.Progress) -> Progress {
                switch progress {
                case .start:
                    return .start
                case .downloading:
                    return .downloadingProgramGuide
                case .unarchiving:
                    return .unarchivingProgramGuide
                case .parsing:
                    return .parsingProgramGuide
                case .complete:
                    return .complete
                }
            }
            progress(steps.map(convert), convert(step))
        })
    }

    func refreshProgramGuideCache(
        from sourceURL: URL,
        cacheURL: URL,
        progress: @escaping ProgressHandler
    ) async throws {
        let xmlData = try await xmlData(from: sourceURL, progress: progress)

        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try FileManager.default.removeItem(at: cacheURL)
        }

        try xmlData.write(to: cacheURL, options: .atomic)
    }

    func xmlData(from sourceURL: URL, progress: @escaping ProgressHandler) async throws -> Data {
        if sourceURL.pathExtension.lowercased() == "xml" {
            return try await loadData(from: sourceURL)
        }

        do {
            return try await extractedXMLData(from: sourceURL, progress: progress)
        } catch {
            logger.error(error)
            return try await loadData(from: sourceURL)
        }
    }

    func extractedXMLData(from sourceURL: URL, progress: @escaping ProgressHandler) async throws -> Data {
        let extractedURLs = try await unarchiver(progress: progress, initiator: .programGuide).unarchive(sourceURL.absoluteString)
        defer { cleanupExtraction(at: extractedURLs) }

        guard let xmlURL = extractedURLs.first(where: { $0.pathExtension.lowercased() == "xml" }) else {
            throw ProgramGuideParser.ParserError.missingXMLFile
        }

        return try Data(contentsOf: xmlURL)
    }

    func loadData(from url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            throw ProgramGuideParser.ParserError.downloadFailed(httpResponse.statusCode)
        }

        return data
    }

    func preparedImageCacheURL(
        for source: String,
        cacheURL: URL,
        reload: Bool,
        progress: @escaping ProgressHandler
    ) async -> URL? {
        let fileManager = FileManager.default
        var isDirectory = ObjCBool(false)
        let cacheExists = fileManager.fileExists(atPath: cacheURL.path, isDirectory: &isDirectory)

        if cacheExists, !reload, isDirectory.boolValue {
            return cacheURL
        }

        if cacheExists {
            try? fileManager.removeItem(at: cacheURL)
        }

        do {
            let extractedURLs = try await unarchiver(progress: progress, initiator: .logos).unarchive(source)
            guard !extractedURLs.isEmpty else {
                return nil
            }

            try cacheImageArchive(from: extractedURLs, to: cacheURL)
            return cacheURL
        } catch {
            logger.error(error)
            return nil
        }
    }

    func cacheImageArchive(from extractedURLs: [URL], to cacheURL: URL) throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: cacheURL.path) {
            try fileManager.removeItem(at: cacheURL)
        }

        if let extractionRoot = extractedURLs.compactMap(extractionRoot(for:)).first {
            try fileManager.moveItem(at: extractionRoot, to: cacheURL)
            return
        }

        try fileManager.createDirectory(
            at: cacheURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        for extractedURL in extractedURLs {
            let destinationURL = cacheURL.appendingPathComponent(extractedURL.lastPathComponent)

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: extractedURL, to: destinationURL)
        }

        cleanupExtraction(at: extractedURLs)
    }

    func resolvedStreamLogo(for stream: PlaylistParser.Stream, imageRootURL: URL) -> PlaylistParser.Stream {
        if hasResolvedImageURL(stream.tvgLogo) {
            return stream
        }

        guard let resolvedLogoURL = resolvedStreamLogoURL(for: stream, imageRootURL: imageRootURL) else {
            return stream
        }

        return PlaylistParser.Stream(
            title: stream.title,
            url: stream.url,
            tvgLogo: resolvedLogoURL.absoluteString,
            tvgID: stream.tvgID,
            tvgName: stream.tvgName,
            groupTitle: stream.groupTitle
        )
    }

    func resolvedStreamLogoURL(for stream: PlaylistParser.Stream, imageRootURL: URL) -> URL? {
        let fileManager = FileManager.default

        for name in streamImageCandidateNames(for: stream) {
            for candidateURL in streamImageCandidateURLs(for: name, imageRootURL: imageRootURL) {
                if fileManager.fileExists(atPath: candidateURL.path) {
                    return candidateURL
                }
            }
        }

        return nil
    }

    func streamImageCandidateNames(for stream: PlaylistParser.Stream) -> [String] {
        var names: [String] = []
        var seenNames = Set<String>()

        for value in [stream.tvgID, stream.tvgLogo, stream.tvgName, stream.title] {
            guard let name = normalized(value), seenNames.insert(name).inserted else {
                continue
            }

            names.append(name)
        }

        return names
    }

    func streamImageCandidateURLs(for name: String, imageRootURL: URL) -> [URL] {
        [
            imageRootURL.appendingPathComponent(name),
            imageRootURL.appendingPathComponent(name).appendingPathExtension("png"),
            imageRootURL.appendingPathComponent(name).appendingPathExtension("jpg"),
            imageRootURL.appendingPathComponent(name).appendingPathExtension("jpeg")
        ]
    }

    func hasResolvedImageURL(_ value: String?) -> Bool {
        guard let value = normalized(value), let url = URL(string: value) else {
            return false
        }

        return url.scheme != nil
    }

    private func unarchiver(progress: @escaping ProgressHandler, initiator: ProgressInitiator) -> Unarchiver {
        Unarchiver(onProgress: { steps, step, _ in
            func convert(_ progress: Unarchiver.Progress) -> Progress {
                switch progress {
                case .start:
                    return .start
                case .downloading:
                    switch initiator {
                    case .programGuide:
                        return .downloadingProgramGuide
                    case .logos:
                        return .downloadingLogos
                    }
                case .unarchiving:
                    switch initiator {
                    case .programGuide:
                        return .unarchivingProgramGuide
                    case .logos:
                        return .unarchivingLogos
                    }
                case .complete:
                    return .complete
                }
            }
            progress(steps.map(convert), convert(step))
        })
    }

    func resolvedGuideCacheURLs(for playlists: [PlaylistParser.Playlist]) -> Set<URL> {
        Set(
            playlists.compactMap { playlist in
                guard let source = programGuideSource(for: playlist) else {
                    return nil
                }

                return guideCacheURL(for: source)
            }
        )
    }

    func resolvedImageCacheURLs(for playlists: [PlaylistParser.Playlist]) -> Set<URL> {
        Set(
            playlists.compactMap { playlist in
                guard let source = normalized(playlist.imageURL) else {
                    return nil
                }

                return imageCacheURL(for: source)
            }
        )
    }

    func programGuideSource(for playlist: PlaylistParser.Playlist) -> String? {
        normalized(playlist.tvgURL) ?? normalized(playlist.xTvgURL)
    }

    func guideCacheURL(for source: String) -> URL {
        cacheDirectoryURL
            .appendingPathComponent(sha256Hex(for: source))
            .appendingPathExtension("xml")
    }

    func imageCacheURL(for source: String) -> URL {
        cacheDirectoryURL
            .appendingPathComponent(sha256Hex(for: source), isDirectory: true)
    }

    func ensureCacheDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: cacheDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func resolvedURL(from rawValue: String) -> URL? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmedValue), url.scheme != nil {
            return url
        }

        return URL(fileURLWithPath: (trimmedValue as NSString).expandingTildeInPath)
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

    func hasArchiveExtension(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        return path.hasSuffix(".zip")
            || path.hasSuffix(".tar.gz")
            || path.hasSuffix(".tar")
            || path.hasSuffix(".gz")
    }

    func streamCandidateNames(for stream: PlaylistParser.Stream) -> Set<String> {
        Set(
            [
                normalized(stream.tvgName),
                normalized(stream.title)
            ].compactMap { $0 }
        )
    }

    func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    func sha256Hex(for value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func cacheKey(for content: PlaylistItem.Content) -> CacheKey {
        CacheKey(
            name: content.identity.name,
            date: content.identity.date
        )
    }
}

extension FactoryKit.Container {

    @MainActor
    var playlistService: Factory<PlaylistServiceInterface> {
        self { PlaylistService() }.singleton
    }
}
