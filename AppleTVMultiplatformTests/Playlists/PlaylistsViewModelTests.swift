import Foundation
import SwiftData
import Testing
import FactoryKit
import FactoryTesting
import os
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

    @Test func localLogoURLReturnsAvailableBackupURL() {
        let source = "https://example.com/logo.png"
        let expectedURL = URL(fileURLWithPath: "/permanent/logos/logo.png")
        let service = LocalLogoMockPlaylistLogoStorageService(
            localURLs: [source: expectedURL]
        )
        Container.shared.databaseService.register {
            DatabaseService(isStoredInMemoryOnly: true)
        }
        Container.shared.playlistLogoStorageService.register { service }
        let viewModel = PlaylistsViewModel()

        let result = viewModel.localLogoURL(for: source)

        #expect(result == expectedURL)
        #expect(service.recordedLocalLogoURLSources() == [source])
    }

    @Test func localLogoURLReturnsNilWhenBackupIsUnavailable() {
        let source = "https://example.com/missing-logo.png"
        let service = LocalLogoMockPlaylistLogoStorageService(localURLs: [:])
        Container.shared.databaseService.register {
            DatabaseService(isStoredInMemoryOnly: true)
        }
        Container.shared.playlistLogoStorageService.register { service }
        let viewModel = PlaylistsViewModel()

        let result = viewModel.localLogoURL(for: source)

        #expect(result == nil)
        #expect(service.recordedLocalLogoURLSources() == [source])
    }

    @MainActor
    @Test func deletePlaylistDeletesSelectedPlaylistAndClearsCache() async throws {
        let deletedIdentity = PlaylistItem.Identity(
            name: "Deleted",
            date: Date(timeIntervalSince1970: 100)
        )
        let remainingIdentity = PlaylistItem.Identity(
            name: "Remaining",
            date: Date(timeIntervalSince1970: 200)
        )
        let deletedPlaylist = makePlaylist(
            identity: deletedIdentity,
            icon: "https://example.com/deleted.png",
            url: Data("https://example.com/deleted.m3u".utf8),
            data: Data("stored-deleted-data".utf8)
        )
        let remainingPlaylist = makePlaylist(identity: remainingIdentity)
        let database = try makeDatabaseService(items: [deletedPlaylist, remainingPlaylist])
        let restoredPlaylist = RestoredPlaylist(
            name: deletedIdentity.name,
            date: deletedIdentity.date,
            icon: deletedPlaylist.icon,
            url: Data("https://example.com/deleted.m3u".utf8),
            data: Data("#EXTM3U deleted".utf8),
            isStoredInMemoryOnly: false
        )
        let playlistAddService = DeletePlaylistMockPlaylistAddService(
            restoredPlaylist: restoredPlaylist
        )
        let playlistService = DeletePlaylistMockPlaylistService()
        let expectedPreparedPlaylist = try #require(PreparedPlaylist(deletedPlaylist))
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { playlistAddService }
        Container.shared.playlistService.register { playlistService }
        let viewModel = PlaylistsViewModel()
        viewModel.updatePlaylists()
        viewModel.selectedPlaylist = deletedPlaylist

        viewModel.deletePlaylist(deletedPlaylist)

        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())

        #expect(storedPlaylists.compactMap(\.identity) == [remainingIdentity])
        #expect(viewModel.playlists.compactMap(\.identity) == [remainingIdentity])
        #expect(viewModel.selectedPlaylist == nil)

        try await waitForClearCache(on: playlistService)

        let restoreCalls = await playlistAddService.recordedRestoreCalls()
        let restoreCall = try #require(restoreCalls.first)
        let clearCacheCalls = await playlistService.recordedClearCacheCalls()
        let clearedContent = try #require(clearCacheCalls.first)

        #expect(restoreCalls.count == 1)
        #expect(restoreCall.preparedPlaylist == expectedPreparedPlaylist)
        #expect(restoreCall.pin == nil)
        #expect(clearCacheCalls.count == 1)
        #expect(clearedContent.identity == restoredPlaylist.content.identity)
        #expect(clearedContent.url == restoredPlaylist.content.url)
        #expect(clearedContent.data == restoredPlaylist.content.data)
        #expect(clearedContent.isStoredInMemoryOnly == restoredPlaylist.content.isStoredInMemoryOnly)
    }

    @MainActor
    @Test func deletePlaylistKeepsDifferentSelection() async throws {
        let deletedIdentity = PlaylistItem.Identity(
            name: "Deleted",
            date: Date(timeIntervalSince1970: 100)
        )
        let selectedIdentity = PlaylistItem.Identity(
            name: "Selected",
            date: Date(timeIntervalSince1970: 200)
        )
        let deletedPlaylist = makePlaylist(identity: deletedIdentity)
        let selectedPlaylist = makePlaylist(identity: selectedIdentity)
        let database = try makeDatabaseService(items: [deletedPlaylist, selectedPlaylist])
        let playlistAddService = DeletePlaylistMockPlaylistAddService(
            restoredPlaylist: RestoredPlaylist(
                name: deletedIdentity.name,
                date: deletedIdentity.date,
                icon: nil,
                url: Data("https://example.com/deleted.m3u".utf8),
                data: Data("#EXTM3U deleted".utf8),
                isStoredInMemoryOnly: false
            )
        )
        let playlistService = DeletePlaylistMockPlaylistService()
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { playlistAddService }
        Container.shared.playlistService.register { playlistService }
        let viewModel = PlaylistsViewModel()
        viewModel.updatePlaylists()
        viewModel.selectedPlaylist = selectedPlaylist

        viewModel.deletePlaylist(deletedPlaylist)

        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())

        #expect(storedPlaylists.compactMap(\.identity) == [selectedIdentity])
        #expect(viewModel.playlists.compactMap(\.identity) == [selectedIdentity])
        #expect(viewModel.selectedPlaylist?.identity == selectedIdentity)

        try await waitForClearCache(on: playlistService)

        #expect(await playlistAddService.recordedRestoreCalls().count == 1)
        #expect(await playlistService.recordedClearCacheCalls().count == 1)
    }

    private func makeDatabaseService(items: [PlaylistItem]) throws -> DatabaseService {
        let database = DatabaseService(isStoredInMemoryOnly: true)

        for item in items {
            database.mainContext.insert(item)
        }

        try database.mainContext.save()

        return database
    }

    private func makePlaylist(
        identity: PlaylistItem.Identity,
        icon: String? = nil,
        url: Data = Data("https://example.com/playlist.m3u".utf8),
        data: Data = Data("stored-playlist-data".utf8)
    ) -> PlaylistItem {
        PlaylistItem(
            name: identity.name,
            date: identity.date,
            icon: icon,
            url: url,
            data: data,
            salt: nil,
            encrypted: false
        )
    }

    private func waitForClearCache(
        on playlistService: DeletePlaylistMockPlaylistService
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))

        while await playlistService.recordedClearCacheCalls().isEmpty {
            guard clock.now < deadline else {
                Issue.record("Timed out waiting for clearCache.")
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

private nonisolated final class LocalLogoMockPlaylistLogoStorageService:
    PlaylistLogoStorageServiceInterface {

    private let localURLs: [String: URL]
    private let localLogoURLSources = OSAllocatedUnfairLock(initialState: [String]())

    init(localURLs: [String: URL]) {
        self.localURLs = localURLs
    }

    func recordedLocalLogoURLSources() -> [String] {
        localLogoURLSources.withLock { $0 }
    }

    func backupLogo(from source: String) async throws -> URL {
        Issue.record("Unexpected backupLogo call.")
        throw PlaylistLogoStorageService.Error.invalidSource
    }

    func localLogoURL(for source: String) -> URL? {
        localLogoURLSources.withLock { $0.append(source) }
        return localURLs[source]
    }
}

private actor DeletePlaylistMockPlaylistAddService: PlaylistAddServiceInterface {

    struct RestoreCall: Sendable {
        let preparedPlaylist: PreparedPlaylist
        let pin: String?
    }

    private let restoredPlaylist: RestoredPlaylist
    private var restoreCalls: [RestoreCall] = []

    init(restoredPlaylist: RestoredPlaylist) {
        self.restoredPlaylist = restoredPlaylist
    }

    func recordedRestoreCalls() -> [RestoreCall] {
        restoreCalls
    }

    func preparePlaylist(
        name: String?,
        urlString: String,
        pin: String?,
        urlTvg: String?,
        urlImg: String?,
        tvgLogo: String?,
        progress: ProgressHandler
    ) async throws -> PreparedPlaylist {
        Issue.record("Unexpected preparePlaylist call.")
        throw PlaylistAddService.Error.invalidPreparedPlaylist
    }

    func encryptPlaylist(
        _ preparedPlaylist: PreparedPlaylist,
        pin: String
    ) async throws -> PreparedPlaylist {
        Issue.record("Unexpected encryptPlaylist call.")
        throw PlaylistAddService.Error.invalidPreparedPlaylist
    }

    func restorePlaylist(
        _ preparedPlaylist: PreparedPlaylist,
        pin: String?
    ) async throws -> RestoredPlaylist {
        restoreCalls.append(.init(preparedPlaylist: preparedPlaylist, pin: pin))
        return restoredPlaylist
    }
}

private actor DeletePlaylistMockPlaylistService: PlaylistServiceInterface {

    private var clearCacheCalls: [PlaylistItem.Content] = []

    func recordedClearCacheCalls() -> [PlaylistItem.Content] {
        clearCacheCalls
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadProgramGuide: Bool,
        progress: @escaping ProgressHandler
    ) async throws -> [PlaylistParser.Playlist] {
        Issue.record("Unexpected playlists(reloadProgramGuide:) call.")
        return []
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadPlaylist: Bool,
        progress: @escaping ProgressHandler
    ) async throws -> [PlaylistParser.Playlist] {
        Issue.record("Unexpected playlists(reloadPlaylist:) call.")
        return []
    }

    func programGuide(
        for content: PlaylistItem.Content,
        stream: PlaylistParser.Stream
    ) async -> ProgramGuide? {
        Issue.record("Unexpected programGuide call.")
        return nil
    }

    func programGuides(
        for content: PlaylistItem.Content,
        since: Date
    ) async -> [ProgramGuide] {
        Issue.record("Unexpected programGuides call.")
        return []
    }

    func clearCache(for content: PlaylistItem.Content) {
        clearCacheCalls.append(content)
    }
}
