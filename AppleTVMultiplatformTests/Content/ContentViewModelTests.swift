import Foundation
import SwiftData
import Testing
import FactoryKit
import FactoryTesting
#if canImport(UIKit)
import UIKit
#endif
@testable import Bro_Player

@Suite(.container)
struct ContentViewModelTests {

    @MainActor
    @Test func onPlaylistSelectedStoresRestoredContentAndClearsSelectedStream() async throws {
        let date = Date(timeIntervalSince1970: 100)
        let playlist = try await makePlaylistItem(
            name: "Playlist",
            date: date,
            encrypted: false
        )
        let database = try makeDatabaseService(items: [playlist])
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { PlaylistAddService() }
        let viewModel = ContentViewModel()
        viewModel.selectedPlaylistContent = .init(
            identity: .init(name: "Old", date: .distantPast),
            url: Data("https://example.com/old.m3u".utf8),
            data: Data("#EXTM3U".utf8),
            isStoredInMemoryOnly: false
        )
        viewModel.selectedPlaylistStream = .init(
            title: "Existing",
            url: "https://example.com/existing.m3u8",
            tvgLogo: nil,
            tvgID: nil,
            tvgName: nil,
            groupTitle: nil
        )
        viewModel.selectedPlaylist = .init(name: "Playlist", date: date)

        await viewModel.onPlaylistSelected()

        let selectedContent = try #require(viewModel.selectedPlaylistContent)

        #expect(selectedContent.identity == .init(name: "Playlist", date: date))
        #expect(selectedContent.url == Data("https://example.com/Playlist.m3u".utf8))
        #expect(selectedContent.data == Data("#EXTM3U".utf8))
        #expect(selectedContent.isStoredInMemoryOnly == false)
        #expect(viewModel.selectedPlaylistStream == nil)
        #expect(viewModel.isShowingPlaylistDecryptPin == nil)
    }

    @MainActor
    @Test func onPlaylistSelectedShowsDecryptPinForEncryptedPlaylist() async throws {
        let date = Date(timeIntervalSince1970: 200)
        let playlist = try await makePlaylistItem(
            name: "Encrypted",
            date: date,
            encrypted: true
        )
        let database = try makeDatabaseService(items: [playlist])
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { PlaylistAddService() }
        let viewModel = ContentViewModel()
        viewModel.selectedPlaylistContent = .init(
            identity: .init(name: "Old", date: .distantPast),
            url: Data("https://example.com/old.m3u".utf8),
            data: Data("#EXTM3U".utf8),
            isStoredInMemoryOnly: false
        )
        viewModel.selectedPlaylistStream = .init(
            title: "Existing",
            url: "https://example.com/existing.m3u8",
            tvgLogo: nil,
            tvgID: nil,
            tvgName: nil,
            groupTitle: nil
        )
        
        viewModel.selectedPlaylist = .init(name: "Encrypted", date: date)

        await viewModel.onPlaylistSelected()

        #expect(viewModel.selectedPlaylistContent == nil)
        #expect(viewModel.selectedPlaylistStream == nil)
        #expect(viewModel.isShowingPlaylistDecryptPin == playlist.identity)
    }
}

private extension ContentViewModelTests {

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
        encrypted: Bool
    ) async throws -> PlaylistItem {
        let playlistData = Data("#EXTM3U".utf8)
        let storedData = encrypted
            ? Data("encrypted-playlist".utf8)
            : try await DataCompressor().compress(playlistData)

        return PlaylistItem(
            name: name,
            date: date,
            icon: nil,
            url: Data("https://example.com/\(name).m3u".utf8),
            data: storedData,
            salt: encrypted ? Data("salt".utf8) : nil,
            encrypted: encrypted
        )
    }
}
