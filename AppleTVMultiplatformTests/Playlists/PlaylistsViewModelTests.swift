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
struct PlaylistsViewModelTests {

    @Test func updatePlaylists() throws {
        let earlierDate = Date(timeIntervalSince1970: 100)
        let laterDate = Date(timeIntervalSince1970: 200)
        let database = try makeDatabaseService(
            items: [
                PlaylistItem(
                    name: "Later",
                    date: laterDate,
                    icon: nil,
                    url: nil,
                    data: nil,
                    salt: nil,
                    encrypted: false
                ),
                PlaylistItem(
                    name: nil,
                    date: earlierDate,
                    icon: nil,
                    url: nil,
                    data: nil,
                    salt: nil,
                    encrypted: false
                ),
                PlaylistItem(
                    name: "Earlier",
                    date: earlierDate,
                    icon: nil,
                    url: nil,
                    data: nil,
                    salt: nil,
                    encrypted: false
                ),
                PlaylistItem(
                    name: "Without date",
                    date: nil,
                    icon: nil,
                    url: nil,
                    data: nil,
                    salt: nil,
                    encrypted: false
                )
            ]
        )
        
        Container.shared.databaseService.register { database }
        
        let viewModel = PlaylistsViewModel()

        #expect(viewModel.playlists.isEmpty)
        
        viewModel.updatePlaylists()

        #expect(viewModel.playlists.count == 2)
        #expect(viewModel.playlists.compactMap(\.name) == ["Later", "Earlier"])
        #expect(viewModel.playlists.compactMap(\.date) == [laterDate, earlierDate])
    }

    @Test func onPlaylistSelection() throws {
        let date = Date(timeIntervalSince1970: 100)
        Container.shared.databaseService.register { DatabaseService(isStoredInMemoryOnly: true) }
        let viewModel = PlaylistsViewModel()

        #expect(viewModel.onPlaylistSelection() == nil)

        let playlist = PlaylistItem(
            name: "Playlist",
            date: date,
            icon: nil,
            url: nil,
            data: nil,
            salt: nil,
            encrypted: false
        )
        viewModel.selectedPlaylist = playlist

        #expect(viewModel.onPlaylistSelection() == .init(name: "Playlist", date: date))
    }
    
    @Test func updateSelection() throws {
        let earlierDate = Date(timeIntervalSince1970: 100)
        let laterDate = Date(timeIntervalSince1970: 200)
        let database = try makeDatabaseService(
            items: [
                PlaylistItem(
                    name: "Later",
                    date: laterDate,
                    icon: nil,
                    url: nil,
                    data: nil,
                    salt: nil,
                    encrypted: false
                ),
                PlaylistItem(
                    name: "Earlier",
                    date: earlierDate,
                    icon: nil,
                    url: nil,
                    data: nil,
                    salt: nil,
                    encrypted: false
                ),
            ]
        )
        
        Container.shared.databaseService.register { database }
        
        let viewModel = PlaylistsViewModel()
        
        #expect(viewModel.onPlaylistSelection() == nil)
        
        viewModel.updateSelection(.init(name: "Earlier", date: earlierDate))

        #expect(viewModel.onPlaylistSelection() == .init(name: "Earlier", date: earlierDate))
    }

    private func makeDatabaseService(items: [PlaylistItem]) throws -> DatabaseService {
        let database = DatabaseService(isStoredInMemoryOnly: true)

        for item in items {
            database.mainContext.insert(item)
        }

        try database.mainContext.save()

        return database
    }
}
