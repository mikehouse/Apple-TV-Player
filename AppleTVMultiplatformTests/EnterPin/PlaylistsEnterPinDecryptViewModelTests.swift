import FactoryKit
import FactoryTesting
import Foundation
import SwiftData
import Testing
@testable import Bro_Player

@Suite(.container)
struct PlaylistsEnterPinDecryptViewModelTests {

    @MainActor
    @Test func initialState() {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        let playlistAddService = MockPlaylistAddService()
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { playlistAddService }

        let viewModel = PlaylistsEnterPinDecryptViewModel(
            identity: .init(name: "Playlist", date: Date(timeIntervalSince1970: 100))
        )

        #expect(viewModel.pin == "")
        #expect(viewModel.showAlert == false)
        #expect(viewModel.message == "")
    }

    @MainActor
    @Test func onPinInputRestoresMatchingEncryptedPlaylist() async throws {
        let identity = PlaylistItem.Identity(
            name: "Encrypted playlist",
            date: Date(timeIntervalSince1970: 100)
        )
        let storedPlaylist = PlaylistItem(
            name: identity.name,
            date: identity.date,
            icon: "https://example.com/icon.png",
            url: Data("encrypted-url".utf8),
            data: Data("encrypted-data".utf8),
            salt: Data("salt".utf8),
            encrypted: true
        )
        let database = try makeDatabaseService(items: [storedPlaylist])
        let restoredPlaylist = RestoredPlaylist(
            name: identity.name,
            date: identity.date,
            icon: storedPlaylist.icon,
            url: Data("https://example.com/playlist.m3u".utf8),
            data: Data("#EXTM3U".utf8),
            isStoredInMemoryOnly: true
        )
        let playlistAddService = MockPlaylistAddService(restoredPlaylist: restoredPlaylist)
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { playlistAddService }
        let viewModel = PlaylistsEnterPinDecryptViewModel(identity: identity)
        viewModel.pin = "1234"

        let result = await viewModel.onPinInput()
        let content = try #require(result)
        let restoreCall = try #require(playlistAddService.restoreCalls.first)
        let storedURL = try #require(storedPlaylist.url)
        let storedData = try #require(storedPlaylist.data)

        #expect(playlistAddService.restoreCalls.count == 1)
        #expect(
            restoreCall.preparedPlaylist == PreparedPlaylist(
                name: identity.name,
                date: identity.date,
                icon: storedPlaylist.icon,
                url: storedURL,
                data: storedData,
                salt: storedPlaylist.salt,
                encrypted: true
            )
        )
        #expect(restoreCall.pin == "1234")
        #expect(content.identity == restoredPlaylist.content.identity)
        #expect(content.url == restoredPlaylist.content.url)
        #expect(content.data == restoredPlaylist.content.data)
        #expect(content.isStoredInMemoryOnly == restoredPlaylist.content.isStoredInMemoryOnly)
        #expect(viewModel.showAlert == false)
        #expect(viewModel.message == "")
    }

    @MainActor
    @Test func onPinInputReturnsNilWhenPlaylistIsMissing() async throws {
        let requestedIdentity = PlaylistItem.Identity(
            name: "Playlist",
            date: Date(timeIntervalSince1970: 100)
        )
        let storedIdentity = PlaylistItem.Identity(
            name: requestedIdentity.name,
            date: Date(timeIntervalSince1970: 200)
        )
        let database = try makeDatabaseService(
            items: [makePlaylist(identity: storedIdentity, encrypted: true)]
        )
        let playlistAddService = MockPlaylistAddService()
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { playlistAddService }
        let viewModel = PlaylistsEnterPinDecryptViewModel(identity: requestedIdentity)

        let content = await viewModel.onPinInput()

        #expect(content == nil)
        #expect(playlistAddService.restoreCalls.isEmpty)
        #expect(viewModel.showAlert == false)
        #expect(viewModel.message == "")
    }

    @MainActor
    @Test func onPinInputReturnsNilWhenPlaylistIsNotEncrypted() async throws {
        let identity = PlaylistItem.Identity(
            name: "Plain playlist",
            date: Date(timeIntervalSince1970: 100)
        )
        let database = try makeDatabaseService(
            items: [makePlaylist(identity: identity, encrypted: false)]
        )
        let playlistAddService = MockPlaylistAddService()
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { playlistAddService }
        let viewModel = PlaylistsEnterPinDecryptViewModel(identity: identity)

        let content = await viewModel.onPinInput()

        #expect(content == nil)
        #expect(playlistAddService.restoreCalls.isEmpty)
        #expect(viewModel.showAlert == false)
        #expect(viewModel.message == "")
    }

    @MainActor
    @Test func onPinInputReturnsNilWhenStoredPlaylistIsIncomplete() async throws {
        let identity = PlaylistItem.Identity(
            name: "Incomplete playlist",
            date: Date(timeIntervalSince1970: 100)
        )
        let database = try makeDatabaseService(
            items: [
                makePlaylist(
                    identity: identity,
                    encrypted: true,
                    url: nil
                )
            ]
        )
        let playlistAddService = MockPlaylistAddService()
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { playlistAddService }
        let viewModel = PlaylistsEnterPinDecryptViewModel(identity: identity)

        let content = await viewModel.onPinInput()

        #expect(content == nil)
        #expect(playlistAddService.restoreCalls.isEmpty)
        #expect(viewModel.showAlert == false)
        #expect(viewModel.message == "")
    }

    @MainActor
    @Test func onPinInputShowsAlertWhenRestoreFails() async throws {
        let identity = PlaylistItem.Identity(
            name: "Encrypted playlist",
            date: Date(timeIntervalSince1970: 100)
        )
        let database = try makeDatabaseService(
            items: [makePlaylist(identity: identity, encrypted: true)]
        )
        let playlistAddService = MockPlaylistAddService(restoreError: .invalidPin)
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { playlistAddService }
        let viewModel = PlaylistsEnterPinDecryptViewModel(identity: identity)
        viewModel.pin = "wrong pin"

        let content = await viewModel.onPinInput()
        let restoreCall = try #require(playlistAddService.restoreCalls.first)

        #expect(content == nil)
        #expect(playlistAddService.restoreCalls.count == 1)
        #expect(restoreCall.pin == "wrong pin")
        #expect(viewModel.showAlert == true)
        #expect(viewModel.message == PlaylistAddService.Error.invalidPin.localizedDescription)
    }
}

private extension PlaylistsEnterPinDecryptViewModelTests {

    @MainActor
    func makeDatabaseService(items: [PlaylistItem]) throws -> DatabaseService {
        let database = DatabaseService(isStoredInMemoryOnly: true)

        for item in items {
            database.mainContext.insert(item)
        }

        try database.mainContext.save()
        return database
    }

    @MainActor
    func makePlaylist(
        identity: PlaylistItem.Identity,
        encrypted: Bool,
        url: Data? = Data("stored-url".utf8),
        data: Data? = Data("stored-data".utf8)
    ) -> PlaylistItem {
        PlaylistItem(
            name: identity.name,
            date: identity.date,
            icon: "https://example.com/icon.png",
            url: url,
            data: data,
            salt: Data("salt".utf8),
            encrypted: encrypted
        )
    }
}

private final class MockPlaylistAddService: PlaylistAddServiceInterface, @unchecked Sendable {

    struct RestoreCall {
        let preparedPlaylist: PreparedPlaylist
        let pin: String?
    }

    private let restoredPlaylist: RestoredPlaylist?
    private let restoreError: PlaylistAddService.Error?
    private(set) var restoreCalls: [RestoreCall] = []

    init(
        restoredPlaylist: RestoredPlaylist? = nil,
        restoreError: PlaylistAddService.Error? = nil
    ) {
        self.restoredPlaylist = restoredPlaylist
        self.restoreError = restoreError
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

        if let restoreError {
            throw restoreError
        }

        guard let restoredPlaylist else {
            Issue.record("Unexpected restorePlaylist call.")
            throw PlaylistAddService.Error.invalidPreparedPlaylist
        }

        return restoredPlaylist
    }
}
