import FactoryKit
import FactoryTesting
import Foundation
import Testing
import SwiftData
@testable import Bro_Player

@Suite(.container)
struct AppleTVMultiplatformAppViewModelTests {

    @Test func handleIncomingFileRejectsInvalidPlaylist() throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        Container.shared.databaseService.register { database }
        let viewModel = AppleTVMultiplatformAppViewModel()
        let url = try writePlaylistFile(
            playlist: PlaylistItem(
                name: nil,
                date: nil,
                icon: nil,
                url: nil,
                data: nil,
                salt: nil,
                encrypted: false
            )
        )

        let didHandle = viewModel.handleIncomingFile(url: url)
        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())

        #expect(didHandle == false)
        #expect(viewModel.error?.errorDescription == "Invalid playlist")
        #expect(viewModel.isErrorPresented == true)
        #expect(storedPlaylists.isEmpty)
    }

    @Test func handleIncomingFileRejectsExistingPlaylist() throws {
        let database = try makeDatabaseService(items: [
            makePlaylistItem(name: "Playlist", date: Date(timeIntervalSince1970: 100))
        ])
        Container.shared.databaseService.register { database }
        let viewModel = AppleTVMultiplatformAppViewModel()
        let url = try writePlaylistFile(
            playlist: PlaylistItem(
                name: "Playlist",
                date: Date(timeIntervalSince1970: 100),
                icon: "https://example.com/icon.png",
                url: Data("https://example.com/imported.m3u".utf8),
                data: Data("#EXTM3U imported".utf8),
                salt: nil,
                encrypted: false
            )
        )

        let didHandle = viewModel.handleIncomingFile(url: url)
        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())

        #expect(didHandle == false)
        #expect(viewModel.error?.errorDescription == "Playlist already exists")
        #expect(viewModel.isErrorPresented == true)
        #expect(storedPlaylists.count == 1)
    }

    @Test func handleIncomingFileStoresPlaylistOnSuccess() throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        Container.shared.databaseService.register { database }
        let viewModel = AppleTVMultiplatformAppViewModel()
        let importedPlaylist = makePlaylistItem(
            name: "Playlist",
            date: Date(timeIntervalSince1970: 200),
            icon: "https://example.com/icon.png",
            url: Data("https://example.com/playlist.m3u".utf8),
            data: Data("#EXTM3U".utf8)
        )
        let url = try writePlaylistFile(playlist: importedPlaylist)

        let didHandle = viewModel.handleIncomingFile(url: url)
        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())
        let storedPlaylist = try #require(storedPlaylists.first)

        #expect(didHandle == true)
        #expect(viewModel.error == nil)
        #expect(viewModel.isErrorPresented == false)
        #expect(storedPlaylists.count == 1)
        #expect(storedPlaylist.name == importedPlaylist.name)
        #expect(storedPlaylist.date == importedPlaylist.date)
        #expect(storedPlaylist.icon == importedPlaylist.icon)
        #expect(storedPlaylist.url == importedPlaylist.url)
        #expect(storedPlaylist.data == importedPlaylist.data)
        #expect(storedPlaylist.salt == importedPlaylist.salt)
        #expect(storedPlaylist.encrypted == importedPlaylist.encrypted)
    }

    @Test func handleIncomingFileShowsWrappedDecodingError() throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        Container.shared.databaseService.register { database }
        let viewModel = AppleTVMultiplatformAppViewModel()
        let url = try writePlaylistFile(data: Data(#"{"name":1,"date":0}"#.utf8))

        let didHandle = viewModel.handleIncomingFile(url: url)
        let decodingError = try #require(viewModel.error?.error)
        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())

        #expect(didHandle == false)
        #expect(decodingError.domain == NSCocoaErrorDomain)
        #expect(decodingError.code == 4864)
        #expect(viewModel.isErrorPresented == true)
        #expect(storedPlaylists.isEmpty)
    }
}

private extension AppleTVMultiplatformAppViewModelTests {

    func makeDatabaseService(items: [PlaylistItem]) throws -> DatabaseService {
        let database = DatabaseService(isStoredInMemoryOnly: true)

        for item in items {
            database.mainContext.insert(item)
        }

        try database.mainContext.save()

        return database
    }

    func makePlaylistItem(
        name: String,
        date: Date,
        icon: String? = nil,
        url: Data? = nil,
        data: Data? = nil,
        salt: Data? = nil,
        encrypted: Bool = false
    ) -> PlaylistItem {
        PlaylistItem(
            name: name,
            date: date,
            icon: icon,
            url: url,
            data: data,
            salt: salt,
            encrypted: encrypted
        )
    }

    func writePlaylistFile(playlist: PlaylistItem) throws -> URL {
        try writePlaylistFile(data: JSONEncoder().encode(playlist))
    }

    func writePlaylistFile(data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("playlist")
        try data.write(to: url)
        return url
    }
}
