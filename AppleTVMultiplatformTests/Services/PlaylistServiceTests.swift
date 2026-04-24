import Foundation
import Testing
@testable import Bro_Player

struct PlaylistServiceTests {

    @Test func loadsPlaylistsProgramGuidesAndResolvesStreamGuide() async throws {
        let cacheDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectoryURL) }

        let playlistURL = try resourceURL(named: "test.m3u")
        let programGuideURL = try resourceURL(named: "program-guide.xml.gz")
        let content = try makeContent(
            playlistURL: playlistURL,
            playlistDataString: try playlistString(
                from: playlistURL,
                programGuideURL: programGuideURL
            )
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let playlists = try await service.playlists(for: content, reloadProgramGuide: false)
        let reloadedPlaylists = try await service.playlists(for: content, reloadPlaylist: false)
        let resolvedGuide = await service.programGuide(
            for: content,
            stream: try #require(playlists.first?.streams.first)
        )
        let expectedGuides = try await ProgramGuideParser().parse(archiveURL: programGuideURL)

        #expect(playlists.count == 1)
        #expect(playlists.first?.streams.count == 2)
        #expect(reloadedPlaylists == playlists)
        #expect(resolvedGuide == expectedGuides.first)
        #expect(try cachedXMLFiles(in: cacheDirectoryURL).count == 1)
    }
    
    @Test func programGuidesFilteredByDate() async throws {
        let cacheDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectoryURL) }

        let playlistURL = try resourceURL(named: "test.m3u")
        let programGuideURL = try resourceURL(named: "program-guide.xml.gz")
        let content = try makeContent(
            playlistURL: playlistURL,
            playlistDataString: try playlistString(
                from: playlistURL,
                programGuideURL: programGuideURL
            )
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let playlists = try await service.playlists(for: content, reloadProgramGuide: false)
        #expect(playlists.count == 1)
        let allGuides = await service.programGuides(for: content, since: Date(timeIntervalSince1970: 1))
        #expect(allGuides.count == 2)
        #expect(allGuides.map({ $0.programs.count }).reduce(0, +) == 4)
        let sinceNowGuides = await service.programGuides(for: content, since: Date())
        #expect(sinceNowGuides.isEmpty)
    }
    
    @Test func programGuideSearchByNameAndSuffix() async throws {
        let cacheDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectoryURL) }

        let playlistURL = try resourceURL(named: "test.m3u")
        let programGuideURL = try resourceURL(named: "program-guide.xml.gz")
        let content = try makeContent(
            playlistURL: playlistURL,
            playlistDataString: try playlistString(
                from: playlistURL,
                programGuideURL: programGuideURL
            )
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let _ = try await service.playlists(for: content, reloadProgramGuide: false)
        var stream = PlaylistParser.Stream(
            title: "Pluto TV Trending Now",
            url: "https://stitcher.pluto.tv/stitch/hls/channel/673247127d5da5000817b4d6/master.m3u8",
            tvgLogo: nil, tvgID: nil, tvgName: nil, groupTitle: nil
        )
        var guide = await service.programGuide(for: content, stream: stream)
        #expect(guide?.channel.id == "673247127d5da5000817b4d6")
        #expect(guide?.channel.displayName == "Pluto TV Trending Now")
        
        stream = PlaylistParser.Stream(
            title: "Pluto TV Trending",
            url: "https://stitcher.pluto.tv/stitch/hls/channel/673247127d5da5000817b4d6/master.m3u8",
            tvgLogo: nil, tvgID: nil, tvgName: nil, groupTitle: nil
        )
        guide = await service.programGuide(for: content, stream: stream)
        #expect(guide?.channel.id == "673247127d5da5000817b4d6")
        #expect(guide?.channel.displayName == "Pluto TV Trending Now")
    }

    @Test func loadsProgramGuideFromXTvgURLWhenTvgURLIsMissing() async throws {
        let cacheDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectoryURL) }

        let playlistURL = try resourceURL(named: "test.m3u")
        let programGuideURL = try resourceURL(named: "program-guide.xml.gz")
        let content = try makeContent(
            playlistURL: playlistURL,
            playlistDataString: try playlistString(
                from: playlistURL,
                programGuideURL: programGuideURL,
                guideAttributeName: "x-tvg-url"
            )
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let playlists = try await service.playlists(for: content, reloadProgramGuide: false)
        let resolvedGuide = await service.programGuide(
            for: content,
            stream: try #require(playlists.first?.streams.first)
        )
        let expectedGuides = try await ProgramGuideParser().parse(archiveURL: programGuideURL)

        #expect(playlists.count == 1)
        #expect(playlists.first?.tvgURL == nil)
        #expect(playlists.first?.xTvgURL == programGuideURL.absoluteString)
        #expect(resolvedGuide == expectedGuides.first)
        #expect(try cachedXMLFiles(in: cacheDirectoryURL).count == 1)
    }

    @Test func reusesCachedXMLWhenProgramGuideReloadIsFalse() async throws {
        let workingDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingDirectoryURL) }

        let cacheDirectoryURL = workingDirectoryURL.appendingPathComponent("Cache", isDirectory: true)
        let archiveURL = try copyResource(
            named: "program-guide.xml.gz",
            to: workingDirectoryURL.appendingPathComponent("program-guide.xml.gz")
        )
        let playlistURL = try resourceURL(named: "test.m3u")
        let content = try makeContent(
            playlistURL: playlistURL,
            playlistDataString: try playlistString(
                from: playlistURL,
                programGuideURL: archiveURL
            )
        )

        let firstService = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)
        let initialPlaylists = try await firstService.playlists(for: content, reloadPlaylist: false)
        let expectedGuide = await firstService.programGuide(
            for: content,
            stream: try #require(initialPlaylists.first?.streams.first)
        )

        try FileManager.default.removeItem(at: archiveURL)

        let secondService = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)
        let cachedPlaylists = try await secondService.playlists(for: content, reloadPlaylist: false)
        let cachedGuide = await secondService.programGuide(
            for: content,
            stream: try #require(cachedPlaylists.first?.streams.first)
        )

        #expect(cachedPlaylists == initialPlaylists)
        #expect(cachedGuide == expectedGuide)
        #expect(try cachedXMLFiles(in: cacheDirectoryURL).count == 1)
    }

    @Test func reloadPlaylistUsesPlaylistSourceAndReplacesCachedPlaylists() async throws {
        let workingDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingDirectoryURL) }

        let cacheDirectoryURL = workingDirectoryURL.appendingPathComponent("Cache", isDirectory: true)
        let archiveURL = try copyResource(
            named: "program-guide.xml.gz",
            to: workingDirectoryURL.appendingPathComponent("program-guide.xml.gz")
        )
        let sourcePlaylistURL = workingDirectoryURL.appendingPathComponent("playlist.m3u")
        let initialPlaylistURL = try resourceURL(named: "test.m3u")
        let initialPlaylistString = try playlistString(
            from: initialPlaylistURL,
            programGuideURL: archiveURL
        )
        let updatedPlaylistString = playlistStringWithSingleStream(programGuideURL: archiveURL)
        try updatedPlaylistString.write(to: sourcePlaylistURL, atomically: true, encoding: .utf8)

        var content = try makeContent(
            playlistURL: sourcePlaylistURL,
            playlistDataString: initialPlaylistString
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let initialPlaylists = try await service.playlists(for: content, reloadProgramGuide: false)
        let initialCachedPlaylists = try await service.playlists(for: content, reloadPlaylist: false)
        content = try makeContent(
            playlistURL: sourcePlaylistURL,
            playlistDataString: String(contentsOf: sourcePlaylistURL, encoding: .utf8)
        )
        let reloadedPlaylists = try await service.playlists(for: content, reloadPlaylist: true)
        let cachedPlaylists = try await service.playlists(for: content, reloadProgramGuide: false)
        let reloadedGuide = await service.programGuide(
            for: content,
            stream: try #require(reloadedPlaylists.first?.streams.first)
        )

        #expect(initialPlaylists.first?.streams.count == 2)
        #expect(initialCachedPlaylists.first?.streams.count == 2)
        #expect(reloadedPlaylists.first?.streams.count == 1)
        #expect(cachedPlaylists.first?.streams.count == 1)
        #expect(cachedPlaylists == reloadedPlaylists)
        #expect(cachedPlaylists.first?.streams.first?.title == "Pluto TV Spotlight")
        #expect(reloadedGuide?.channel.displayName == "Pluto TV Spotlight")
    }

    @Test func clearCacheRemovesMemoryAndDiskCache() async throws {
        let workingDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingDirectoryURL) }

        let cacheDirectoryURL = workingDirectoryURL.appendingPathComponent("Cache", isDirectory: true)
        let archiveURL = try copyResource(
            named: "program-guide.xml.gz",
            to: workingDirectoryURL.appendingPathComponent("program-guide.xml.gz")
        )
        let playlistURL = try resourceURL(named: "test.m3u")
        let content = try makeContent(
            playlistURL: playlistURL,
            playlistDataString: try playlistString(
                from: playlistURL,
                programGuideURL: archiveURL
            )
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let playlists = try await service.playlists(for: content, reloadProgramGuide: false)
        let stream = try #require(playlists.first?.streams.first)
        let guideBeforeClear = await service.programGuide(for: content, stream: stream)

        #expect(guideBeforeClear != nil)
        #expect(try cachedXMLFiles(in: cacheDirectoryURL).count == 1)

        await service.clearCache(for: content)
        try FileManager.default.removeItem(at: archiveURL)

        let guideAfterClear = await service.programGuide(for: content, stream: stream)

        #expect(guideAfterClear == nil)
        #expect(try cachedXMLFiles(in: cacheDirectoryURL).isEmpty)
    }

    @Test func doesNotPersistProgramGuideXMLWhenContentIsStoredInMemoryOnly() async throws {
        let workingDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingDirectoryURL) }

        let cacheDirectoryURL = workingDirectoryURL.appendingPathComponent("Cache", isDirectory: true)
        let archiveURL = try copyResource(
            named: "program-guide.xml.gz",
            to: workingDirectoryURL.appendingPathComponent("program-guide.xml.gz")
        )
        let playlistURL = try resourceURL(named: "test.m3u")
        let content = try makeContent(
            playlistURL: playlistURL,
            playlistDataString: try playlistString(
                from: playlistURL,
                programGuideURL: archiveURL
            ),
            isStoredInMemoryOnly: true
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let playlists = try await service.playlists(for: content, reloadProgramGuide: false)
        let stream = try #require(playlists.first?.streams.first)
        let guideBeforeSourceRemoval = await service.programGuide(for: content, stream: stream)

        try FileManager.default.removeItem(at: archiveURL)

        let guideAfterSourceRemoval = await service.programGuide(for: content, stream: stream)

        #expect(guideBeforeSourceRemoval != nil)
        #expect(guideAfterSourceRemoval == guideBeforeSourceRemoval)
        #expect(try cachedXMLFiles(in: cacheDirectoryURL).isEmpty)
    }

    @Test func resolvesStreamLogosFromImageArchivesUsingSearchOrder() async throws {
        let workingDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: workingDirectoryURL) }

        let scenarios = [
            ("Animal Planet.png.zip", "Animal Planet.png"),
            ("9104.png.zip", "9104.png"),
            ("9103.png.zip", "9103.png")
        ]

        for (archiveName, expectedImageName) in scenarios {
            let imageArchiveURL = try resourceURL(named: archiveName)
            let cacheDirectoryURL = workingDirectoryURL.appendingPathComponent(archiveName, isDirectory: true)
            let content = try makeContent(
                playlistURL: imageArchiveURL,
                playlistDataString: playlistStringWithImageArchive(imageArchiveURL: imageArchiveURL)
            )
            let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

            let playlists = try await service.playlists(for: content, reloadProgramGuide: false)
            let logoURL = try resolvedLogoURL(from: playlists)

            #expect(logoURL.isFileURL)
            #expect(logoURL.lastPathComponent == expectedImageName)
            #expect(FileManager.default.fileExists(atPath: logoURL.path))
        }
    }

    @Test func keepsRemoteStreamLogoWhenImageArchiveExists() async throws {
        let cacheDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectoryURL) }

        let imageArchiveURL = try resourceURL(named: "9103.png.zip")
        let remoteLogoURL = "https://example.com/remote-logo.png"
        let content = try makeContent(
            playlistURL: imageArchiveURL,
            playlistDataString: playlistStringWithImageArchive(
                imageArchiveURL: imageArchiveURL,
                tvgLogo: remoteLogoURL
            )
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let playlists = try await service.playlists(for: content, reloadProgramGuide: false)

        #expect(playlists.first?.streams.first?.tvgLogo == remoteLogoURL)
    }

    @Test func clearCacheRemovesExtractedImageArchives() async throws {
        let cacheDirectoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectoryURL) }

        let imageArchiveURL = try resourceURL(named: "9103.png.zip")
        let content = try makeContent(
            playlistURL: imageArchiveURL,
            playlistDataString: playlistStringWithImageArchive(imageArchiveURL: imageArchiveURL)
        )
        let service = PlaylistService(cacheDirectoryURL: cacheDirectoryURL)

        let playlists = try await service.playlists(for: content, reloadProgramGuide: false)
        let logoURL = try resolvedLogoURL(from: playlists)
        let imageDirectoryURL = logoURL.deletingLastPathComponent()

        #expect(FileManager.default.fileExists(atPath: imageDirectoryURL.path))

        await service.clearCache(for: content)

        #expect(!FileManager.default.fileExists(atPath: imageDirectoryURL.path))
    }
}

private extension PlaylistServiceTests {

    static let guidePlaceholder = "${INSERT_TVG_TEST_BUNDLE_URL_HERE}"

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

    func copyResource(named resourceName: String, to destinationURL: URL) throws -> URL {
        let sourceURL = try resourceURL(named: resourceName)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    func playlistString(
        from playlistURL: URL,
        programGuideURL: URL,
        guideAttributeName: String = "url-tvg"
    ) throws -> String {
        try String(contentsOf: playlistURL, encoding: .utf8)
            .replacingOccurrences(
                of: Self.guidePlaceholder,
                with: programGuideURL.absoluteString
            )
            .replacingOccurrences(of: "url-tvg=", with: "\(guideAttributeName)=")
    }

    func playlistStringWithSingleStream(programGuideURL: URL) -> String {
        """
        #EXTM3U url-tvg="\(programGuideURL.absoluteString)"

        #EXTINF:-1 tvg-id="5ba3fb9c4b078e0f37ad34e8" tvg-name="Pluto TV Spotlight" tvg-logo="https://images.pluto.tv/channels/5ba3fb9c4b078e0f37ad34e8/colorLogoPNG.png" group-title="Movies" tvg-chno="10", Pluto TV Spotlight
        https://stitcher.pluto.tv/stitch/hls/channel/5ba3fb9c4b078e0f37ad34e8/master.m3u8
        """
    }

    func playlistStringWithImageArchive(
        imageArchiveURL: URL,
        tvgLogo: String = "9103",
        tvgName: String = "9104",
        title: String = "Animal Planet"
    ) -> String {
        """
        #EXTM3U url-img="\(imageArchiveURL.absoluteString)"

        #EXTINF:-1 tvg-name="\(tvgName)" tvg-logo="\(tvgLogo)",\(title)
        http://94.hlstv.nsk.211.en/239.211.0.1.m3u8
        """
    }

    func makeContent(
        playlistURL: URL,
        playlistDataString: String,
        isStoredInMemoryOnly: Bool = false
    ) throws -> PlaylistItem.Content {
        PlaylistItem.Content(
            identity: .init(
                name: "Playlist",
                date: Date(timeIntervalSince1970: 1)
            ),
            url: Data(playlistURL.absoluteString.utf8),
            data: Data(playlistDataString.utf8),
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
    }

    func cachedXMLFiles(in directoryURL: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "xml" }
    }

    func resolvedLogoURL(from playlists: [PlaylistParser.Playlist]) throws -> URL {
        let logo = try #require(playlists.first?.streams.first?.tvgLogo)
        return try #require(URL(string: logo))
    }
}

private final class BundleLocator: NSObject {}

private enum TestError: Error {
    case missingResource(String)
}
