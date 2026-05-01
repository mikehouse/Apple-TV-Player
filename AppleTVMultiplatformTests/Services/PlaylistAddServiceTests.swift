import Foundation
import Testing
@testable import Bro_Player

struct PlaylistAddServiceTests {

    private let service = PlaylistAddService()

    @Test func preparesCompressedPlaylistWithoutEncryption() async throws {
        let sourceURL = try makePlaylistFile(
            named: "sample.m3u",
            contents: Self.playlistWithHeaderLogo
        )
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let prepared = try await service.preparePlaylist(
            name: nil,
            urlString: sourceURL.absoluteString,
            pin: nil,
            urlTvg: nil,
            urlImg: nil,
            tvgLogo: nil,
            progress: { _, _ in }
        )

        #expect(prepared.name == "sample.m3u")
        #expect(prepared.icon == "https://existing.example/playlist-logo.png")
        #expect(prepared.encrypted == false)
        #expect(prepared.salt == nil)
        #expect(prepared.url == Data(sourceURL.absoluteString.utf8))

        let restored = try await service.restorePlaylist(prepared, pin: nil)

        #expect(restored.name == prepared.name)
        #expect(restored.date == prepared.date)
        #expect(restored.icon == prepared.icon)
        #expect(restored.url == Data(sourceURL.absoluteString.utf8))
        #expect(restored.data == Data(Self.playlistWithHeaderLogo.utf8))
        #expect(restored.isStoredInMemoryOnly == false)
    }

    @Test func preparesEncryptedPlaylistWhenPinIsProvided() async throws {
        let sourceURL = try makePlaylistFile(
            named: "encrypted.m3u",
            contents: Self.playlistWithStreamLogo
        )
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let prepared = try await service.preparePlaylist(
            name: "Custom Name",
            urlString: sourceURL.absoluteString,
            pin: Self.pin,
            urlTvg: nil,
            urlImg: nil,
            tvgLogo: nil,
            progress: { _, _ in }
        )

        let salt = try #require(prepared.salt)

        #expect(prepared.name == "Custom Name")
        #expect(prepared.icon == nil)
        #expect(prepared.encrypted == true)
        #expect(salt.count == 32)
        #expect(prepared.url != Data(sourceURL.absoluteString.utf8))

        let restored = try await service.restorePlaylist(prepared, pin: Self.pin)

        #expect(restored.name == prepared.name)
        #expect(restored.date == prepared.date)
        #expect(restored.icon == prepared.icon)
        #expect(restored.url == Data(sourceURL.absoluteString.utf8))
        #expect(restored.data == Data(Self.playlistWithStreamLogo.utf8))
        #expect(restored.isStoredInMemoryOnly == true)
    }

    @Test func restoringEncryptedPlaylistRequiresPin() async throws {
        let sourceURL = try makePlaylistFile(
            named: "locked.m3u",
            contents: Self.playlistWithStreamLogo
        )
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let prepared = try await service.preparePlaylist(
            name: nil,
            urlString: sourceURL.absoluteString,
            pin: Self.pin,
            urlTvg: nil,
            urlImg: nil,
            tvgLogo: nil,
            progress: { _, _ in }
        )

        do {
            _ = try await service.restorePlaylist(prepared, pin: "   ")
            Issue.record("Expected restorePlaylist to require a PIN for encrypted playlists.")
        } catch let error as PlaylistAddService.Error {
            #expect(error == .pinRequired)
        }
    }

    @Test func throwsInvalidPlaylistForMalformedContent() async throws {
        let sourceURL = try makePlaylistFile(
            named: "invalid.m3u",
            contents: "not a playlist"
        )
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        do {
            _ = try await service.preparePlaylist(
                name: nil,
                urlString: sourceURL.absoluteString,
                pin: nil,
                urlTvg: nil,
                urlImg: nil,
                tvgLogo: nil,
                progress: { _, _ in }
            )
            Issue.record("Expected preparePlaylist to throw for invalid content.")
        } catch let error as PlaylistAddService.Error {
            #expect(error == .invalidPlaylist)
        }
    }

    @Test func injectsProvidedHeaderAttributesWhenMissing() async throws {
        let sourceURL = try makePlaylistFile(
            named: "header-fallbacks.m3u",
            contents: Self.playlistWithHeaderLogo
        )
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let prepared = try await service.preparePlaylist(
            name: nil,
            urlString: sourceURL.absoluteString,
            pin: nil,
            urlTvg: "https://example.com/program-guide.xml",
            urlImg: "https://example.com/icon.png",
            tvgLogo: nil,
            progress: { _, _ in }
        )
        let restored = try await service.restorePlaylist(prepared, pin: nil)
        let playlist = try await parsedPlaylist(from: restored.data)

        #expect(prepared.icon == "https://existing.example/playlist-logo.png")
        #expect(restored.data != Data(Self.playlistWithHeaderLogo.utf8))
        #expect(playlist.tvgURL == "https://example.com/program-guide.xml")
        #expect(playlist.xTvgURL == nil)
        #expect(playlist.imageURL == "https://example.com/icon.png")
    }

    @Test func replaceExistingHeaderAttributesWhenFallbackValuesAreProvided() async throws {
        let sourceURL = try makePlaylistFile(
            named: "existing-header-values.m3u",
            contents: Self.playlistWithXTvgAndImageURLAndTvgLogo
        )
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let prepared = try await service.preparePlaylist(
            name: nil,
            urlString: sourceURL.absoluteString,
            pin: nil,
            urlTvg: "https://example.com/program-guide.xml",
            urlImg: "https://example.com/icon.png",
            tvgLogo: "https://example.com/playlist-logo.png",
            progress: { _, _ in }
        )
        let restored = try await service.restorePlaylist(prepared, pin: nil)
        let playlist = try await parsedPlaylist(from: restored.data)

        #expect(prepared.icon == "https://example.com/playlist-logo.png")
        #expect(restored.data != Data(Self.playlistWithXTvgAndImageURLAndTvgLogo.utf8))
        #expect(playlist.tvgURL == "https://example.com/program-guide.xml")
        #expect(playlist.xTvgURL == "https://existing.example/program-guide.xml")
        #expect(playlist.imageURL == "https://example.com/icon.png")
        #expect(playlist.tvgLogo == "https://example.com/playlist-logo.png")
    }

    @Test func usesProvidedTvgLogoAsIconWhenPlaylistHeaderLogoIsMissing() async throws {
        let sourceURL = try makePlaylistFile(
            named: "playlist-logo-fallback.m3u",
            contents: Self.playlistWithStreamLogo
        )
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let prepared = try await service.preparePlaylist(
            name: nil,
            urlString: sourceURL.absoluteString,
            pin: nil,
            urlTvg: nil,
            urlImg: nil,
            tvgLogo: "https://example.com/playlist-logo.png",
            progress: { _, _ in }
        )
        let restored = try await service.restorePlaylist(prepared, pin: nil)
        let playlist = try await parsedPlaylist(from: restored.data)

        #expect(prepared.icon == "https://example.com/playlist-logo.png")
        #expect(restored.data != Data(Self.playlistWithStreamLogo.utf8))
        #expect(playlist.tvgLogo == "https://example.com/playlist-logo.png")
    }

    @Test func keepsExistingPlaylistHeaderLogoWhenProvidedTvgLogoIsDifferent() async throws {
        let sourceURL = try makePlaylistFile(
            named: "existing-playlist-logo.m3u",
            contents: Self.playlistWithHeaderLogo
        )
        defer { try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent()) }

        let prepared = try await service.preparePlaylist(
            name: nil,
            urlString: sourceURL.absoluteString,
            pin: nil,
            urlTvg: nil,
            urlImg: nil,
            tvgLogo: "https://example.com/playlist-logo.png",
            progress: { _, _ in }
        )
        let restored = try await service.restorePlaylist(prepared, pin: nil)
        let playlist = try await parsedPlaylist(from: restored.data)

        #expect(prepared.icon == "https://example.com/playlist-logo.png")
        #expect(restored.data != Data(Self.playlistWithHeaderLogo.utf8))
        #expect(playlist.tvgLogo == "https://example.com/playlist-logo.png")
    }
}

private extension PlaylistAddServiceTests {

    static let pin = "1234"

    static let playlistWithImageURL = """
#EXTM3U url-img="http://tvguide.sibset.en/channels/borpas_icons.zip"
#EXTINF:-1 tvg-name="9104" tvg-logo="9104",Первый канал
http://94.hlstv.nsk.211.en/239.211.0.1.m3u8
"""

    static let playlistWithStreamLogo = """
#EXTM3U
#EXTINF:-1 tvg-id="1HDMusicTelevision.ru" tvg-logo="https://i.imgur.com/6TjLUuF.png",1HD Music Television
https://sc.id-tv.kz/1hd.m3u8
"""

    static let playlistWithXTvgAndImageURLAndTvgLogo = """
#EXTM3U x-tvg-url="https://existing.example/program-guide.xml" url-img="https://existing.example/icon.zip" tvg-logo="https://existing.example/playlist-logo.png"
#EXTINF:-1 tvg-id="1HDMusicTelevision.ru" tvg-logo="https://i.imgur.com/6TjLUuF.png",1HD Music Television
https://sc.id-tv.kz/1hd.m3u8
"""

    static let playlistWithHeaderLogo = """
#EXTM3U tvg-logo="https://existing.example/playlist-logo.png"
#EXTINF:-1 tvg-id="1HDMusicTelevision.ru" tvg-logo="https://i.imgur.com/6TjLUuF.png",1HD Music Television
https://sc.id-tv.kz/1hd.m3u8
"""

    func makePlaylistFile(named name: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        let fileURL = url.appendingPathComponent(name)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func parsedPlaylist(from data: Data) async throws -> PlaylistParser.Playlist {
        let playlists = try await PlaylistParser(data: data).parse()
        return try #require(playlists.first)
    }
}
