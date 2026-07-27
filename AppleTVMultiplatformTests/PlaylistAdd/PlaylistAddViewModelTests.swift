import Foundation
import SwiftData
import Testing
import FactoryKit
import FactoryTesting
@testable import Bro_Player

@Suite(.container)
struct PlaylistAddViewModelTests {

    @MainActor
    @Test func addPlaylistStoresPreparedPlaylist() async throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        Container.shared.databaseService.register { database }
        let preparedPlaylist = PreparedPlaylist(
            name: "Playlist",
            date: Date(timeIntervalSince1970: 100),
            icon: "https://example.com/icon.png",
            url: Data("https://example.com/playlist.m3u".utf8),
            data: Data("playlist-data".utf8),
            salt: nil,
            encrypted: false
        )
        Container.shared.playlistAddService.register { MockPlaylistAddService(preparedPlaylist: preparedPlaylist) }
        let logoStorageService = MockPlaylistLogoStorageService()
        Container.shared.playlistLogoStorageService.register { logoStorageService }
        let viewModel = PlaylistAddViewModel()
        viewModel.urlString = "https://example.com/playlist.m3u"
        viewModel.urlTvg = "https://example.com/program-guide.xml"
        viewModel.urlImg = "https://example.com/icon.png"
        viewModel.tvgLogo = "https://example.com/playlist-logo.png"

        let didAdd = await viewModel.addPlaylist()

        #expect(didAdd == true)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isShowingError == false)

        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())
        let storedPlaylist = try #require(storedPlaylists.first)
        let preparedIcon = try #require(preparedPlaylist.icon)

        #expect(storedPlaylists.count == 1)
        #expect(storedPlaylist.name == preparedPlaylist.name)
        #expect(storedPlaylist.date == preparedPlaylist.date)
        #expect(storedPlaylist.icon == preparedPlaylist.icon)
        #expect(storedPlaylist.url == preparedPlaylist.url)
        #expect(storedPlaylist.data == preparedPlaylist.data)
        #expect(storedPlaylist.salt == preparedPlaylist.salt)
        #expect(storedPlaylist.encrypted == preparedPlaylist.encrypted)
        #expect(await logoStorageService.recordedSources() == [preparedIcon])
    }

    @MainActor
    @Test func addPlaylistShowsErrorWhenPreparationFails() async throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register { FailingPlaylistAddService() }
        let logoStorageService = MockPlaylistLogoStorageService()
        Container.shared.playlistLogoStorageService.register { logoStorageService }
        let viewModel = PlaylistAddViewModel()
        viewModel.urlString = "https://example.com/invalid.m3u"

        let didAdd = await viewModel.addPlaylist()
        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())

        #expect(didAdd == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isShowingError == true)
        #expect(viewModel.errorMessage == PlaylistAddService.Error.invalidPlaylist.errorDescription)
        #expect(storedPlaylists.isEmpty)
        #expect(await logoStorageService.recordedSources().isEmpty)
    }

    @MainActor
    @Test func canAddRequiresURL() {
        Container.shared.databaseService.register { DatabaseService(isStoredInMemoryOnly: true) }
        Container.shared.playlistAddService.register { FailingPlaylistAddService() }
        Container.shared.playlistLogoStorageService.register { MockPlaylistLogoStorageService() }
        let viewModel = PlaylistAddViewModel()

        #expect(viewModel.canAdd == false)

        viewModel.urlString = "   "
        #expect(viewModel.canAdd == false)

        viewModel.urlString = "https://example.com/playlist.m3u"
        #expect(viewModel.canAdd == true)
    }

    @MainActor
    @Test func selectLogoFileUpdatesTvgLogoWithAbsoluteURL() {
        Container.shared.databaseService.register { DatabaseService(isStoredInMemoryOnly: true) }
        Container.shared.playlistAddService.register { FailingPlaylistAddService() }
        Container.shared.playlistLogoStorageService.register { MockPlaylistLogoStorageService() }
        let viewModel = PlaylistAddViewModel()
        let logoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("playlist logo.png")

        viewModel.selectLogoFile(logoURL)

        #expect(viewModel.tvgLogo == logoURL.absoluteString)
    }

    @MainActor
    @Test func addPlaylistShowsErrorWhenSelectedLocalLogoBackupFails() async throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        let logoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("playlist-logo.png")
        let preparedPlaylist = PreparedPlaylist(
            name: "Playlist",
            date: Date(timeIntervalSince1970: 100),
            icon: logoURL.absoluteString,
            url: Data("https://example.com/playlist.m3u".utf8),
            data: Data("playlist-data".utf8),
            salt: nil,
            encrypted: false
        )
        let logoStorageService = MockPlaylistLogoStorageService(behavior: .fail)
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register {
            MockPlaylistAddService(
                preparedPlaylist: preparedPlaylist,
                expectedTvgLogo: logoURL.absoluteString
            )
        }
        Container.shared.playlistLogoStorageService.register { logoStorageService }
        let viewModel = PlaylistAddViewModel()
        configureValidInput(on: viewModel)
        viewModel.selectLogoFile(logoURL)

        let didAdd = await viewModel.addPlaylist()
        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())
        let preparedIcon = try #require(preparedPlaylist.icon)

        #expect(didAdd == false)
        #expect(viewModel.isShowingError == true)
        #expect(viewModel.errorMessage == PlaylistLogoStorageService.Error.localFileUnavailable.errorDescription)
        #expect(storedPlaylists.isEmpty)
        #expect(await logoStorageService.recordedSources() == [preparedIcon])
    }

    @MainActor
    @Test func addPlaylistStopsWithoutErrorWhenLogoBackupIsCancelled() async throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        let preparedPlaylist = PreparedPlaylist(
            name: "Playlist",
            date: Date(timeIntervalSince1970: 100),
            icon: "https://example.com/icon.png",
            url: Data("https://example.com/playlist.m3u".utf8),
            data: Data("playlist-data".utf8),
            salt: nil,
            encrypted: false
        )
        let logoStorageService = MockPlaylistLogoStorageService(behavior: .cancel)
        Container.shared.databaseService.register { database }
        Container.shared.playlistAddService.register {
            MockPlaylistAddService(preparedPlaylist: preparedPlaylist)
        }
        Container.shared.playlistLogoStorageService.register { logoStorageService }
        let viewModel = PlaylistAddViewModel()
        configureValidInput(on: viewModel)

        let didAdd = await viewModel.addPlaylist()
        let storedPlaylists = try database.mainContext.fetch(FetchDescriptor<PlaylistItem>())
        let preparedIcon = try #require(preparedPlaylist.icon)

        #expect(didAdd == false)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.isShowingError == false)
        #expect(storedPlaylists.isEmpty)
        #expect(await logoStorageService.recordedSources() == [preparedIcon])
    }

    @MainActor
    private func configureValidInput(on viewModel: PlaylistAddViewModel) {
        viewModel.urlString = "https://example.com/playlist.m3u"
        viewModel.urlTvg = "https://example.com/program-guide.xml"
        viewModel.urlImg = "https://example.com/icon.png"
        viewModel.tvgLogo = "https://example.com/playlist-logo.png"
    }
}

private final class MockPlaylistAddService: PlaylistAddServiceInterface {

    private let preparedPlaylist: PreparedPlaylist
    private let expectedTvgLogo: String

    init(
        preparedPlaylist: PreparedPlaylist,
        expectedTvgLogo: String = "https://example.com/playlist-logo.png"
    ) {
        self.preparedPlaylist = preparedPlaylist
        self.expectedTvgLogo = expectedTvgLogo
    }

    func preparePlaylist(
        name: String?,
        urlString: String,
        pin: String?,
        urlTvg: String?,
        urlImg: String?,
        tvgLogo: String?,
        progress: @Sendable ([PlaylistAddService.Progress], PlaylistAddService.Progress) -> Void
    ) async throws -> PreparedPlaylist {
        #expect(name == "")
        #expect(urlString == "https://example.com/playlist.m3u")
        #expect(pin == "")
        #expect(urlTvg == "https://example.com/program-guide.xml")
        #expect(urlImg == "https://example.com/icon.png")
        #expect(tvgLogo == expectedTvgLogo)
        return preparedPlaylist
    }

    func restorePlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String?) async throws -> RestoredPlaylist {
        Issue.record("restorePlaylist should not be called in PlaylistAddViewModelTests.")
        throw PlaylistAddService.Error.invalidPreparedPlaylist
    }
    
    func encryptPlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String) async throws -> PreparedPlaylist {
        .init(name: "", date: .init(), icon: nil, url: .init(), data: .init(), salt: nil, encrypted: false)
    }
}

private actor MockPlaylistLogoStorageService: PlaylistLogoStorageServiceInterface {

    enum Behavior: Sendable {
        case succeed
        case fail
        case cancel
    }

    private let behavior: Behavior
    private var sources: [String] = []

    init(behavior: Behavior = .succeed) {
        self.behavior = behavior
    }

    func recordedSources() -> [String] {
        sources
    }

    func backupLogo(from source: String) async throws -> URL {
        sources.append(source)

        switch behavior {
        case .succeed:
            return URL(fileURLWithPath: "/tmp/playlist-logo.img")
        case .fail:
            throw PlaylistLogoStorageService.Error.localFileUnavailable
        case .cancel:
            throw CancellationError()
        }
    }

    nonisolated func localLogoURL(for source: String) -> URL? {
        nil
    }
}

private final class FailingPlaylistAddService: PlaylistAddServiceInterface {
    func preparePlaylist(
        name: String?,
        urlString: String,
        pin: String?,
        urlTvg: String?,
        urlImg: String?,
        tvgLogo: String?,
        progress: @Sendable ([PlaylistAddService.Progress], PlaylistAddService.Progress) -> Void
    ) async throws -> PreparedPlaylist {
        throw PlaylistAddService.Error.invalidPlaylist
    }

    func restorePlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String?) async throws -> RestoredPlaylist {
        throw PlaylistAddService.Error.invalidPreparedPlaylist
    }
    
    func encryptPlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String) async throws -> PreparedPlaylist {
        .init(name: "", date: .init(), icon: nil, url: .init(), data: .init(), salt: nil, encrypted: false)
    }
}
