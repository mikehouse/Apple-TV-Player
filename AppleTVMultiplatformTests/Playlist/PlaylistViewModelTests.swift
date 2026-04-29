import FactoryKit
import FactoryTesting
import Foundation
import Testing
import SwiftData
@testable import Bro_Player

@Suite(.container)
struct PlaylistViewModelTests {
    
    @Test func titleCoding() async throws {
        let viewModel = PlaylistViewModel(content: makeContent())
        let titles: [String] = [
            "Пятница! HD",
            "Суббота! HD",
            "2х2",
            "Перец International",
            "Fashion ONE HD",
            "ТНТ HD",
            "ТНТ4 HD",
            "СТС HD",
            "СТС Love",
            "Домашний HD",
            "Телекафе"
        ]
        for title in titles {
            let (_, encrypted) = viewModel.encode(title: title)
            let decrypted = viewModel.decode(title: encrypted)
            #expect(title == decrypted)
        }
    }

    @Test func loadStreamsUsesFirstPlaylistFromService() async throws {
        let expectedContent = makeContent()
        let firstPlaylist = makePlaylist(
            streams: [
                .init(
                    title: "One",
                    url: "https://example.com/one.m3u8",
                    tvgLogo: "https://example.com/one.png",
                    tvgID: "1",
                    tvgName: "One HD",
                    groupTitle: nil
                ),
                .init(
                    title: "Two",
                    url: "https://example.com/two.m3u8",
                    tvgLogo: nil,
                    tvgID: "2",
                    tvgName: nil,
                    groupTitle: nil
                )
            ]
        )
        let secondPlaylist = makePlaylist(
            streams: [
                .init(
                    title: "Ignored",
                    url: "https://example.com/ignored.m3u8",
                    tvgLogo: nil,
                    tvgID: "3",
                    tvgName: nil,
                    groupTitle: nil
                )
            ]
        )
        let service = MockPlaylistService(
            result: .success([firstPlaylist, secondPlaylist]),
            programGuide: .init(
                channel: .init(id: "1", displayName: "1", iconURL: nil),
                programs: [
                    .init(title: "1", start: Date().addingTimeInterval(1000), stop: Date().addingTimeInterval(1200))
                ]
            )
        )
        Container.shared.playlistService.register { service }
        let viewModel = PlaylistViewModel(content: expectedContent)

        await viewModel.loadStreams()

        #expect(service.requestedContent == expectedContent)
        #expect(service.requestedReloadProgramGuide == false)
        #expect(viewModel.streams == [firstPlaylist.streams])
    }
    
    @Test func loadStreamsDoesReloadGuidesWhenEmpty() async throws {
        let expectedContent = makeContent()
        let playlist = makePlaylist(
            streams: [
                .init(
                    title: "Ignored",
                    url: "https://example.com/ignored.m3u8",
                    tvgLogo: nil,
                    tvgID: "3",
                    tvgName: nil,
                    groupTitle: nil
                )
            ]
        )
        let service = MockPlaylistService(result: .success([playlist]))
        Container.shared.playlistService.register { service }
        let viewModel = PlaylistViewModel(content: expectedContent)

        #expect(service.requestedReloadProgramGuide == nil)
        await viewModel.loadStreams()

        #expect(service.requestedContent == expectedContent)
        #expect(service.requestedReloadProgramGuide == true)
    }

    @Test func loadStreamsStoresErrorAndClearsStreamsOnFailure() async throws {
        let service = MockPlaylistService(result: .failure(MockError.failed))
        Container.shared.playlistService.register { service }
        let viewModel = PlaylistViewModel(content: makeContent())

        await viewModel.loadStreams()

        #expect(viewModel.streams.isEmpty)
        #expect(viewModel.errorMessage == MockError.failed.errorDescription)
    }

    @Test func titlePrefersTvgNameWhenPresent() {
        let viewModel = PlaylistViewModel(content: makeContent())

        #expect(
            viewModel.title(
                for: .init(
                    title: "Fallback",
                    url: "https://example.com/fallback.m3u8",
                    tvgLogo: nil,
                    tvgID: nil,
                    tvgName: " Preferred ",
                    groupTitle: nil
                )
            ) == "Preferred"
        )
        #expect(
            viewModel.title(
                for: .init(
                    title: "Fallback",
                    url: "https://example.com/fallback.m3u8",
                    tvgLogo: nil,
                    tvgID: nil,
                    tvgName: "   ",
                    groupTitle: nil
                )
            ) == "Fallback"
        )
    }
    
    @Test func streamsNoOrder() async throws {
        let expectedContent = makeContent()
        let playlist = makePlaylist(
            streams: [
                .init(
                    title: "Bc",
                    url: "https://example.com/two.m3u8",
                    tvgLogo: nil,
                    tvgID: "2",
                    tvgName: nil,
                    groupTitle: "AA"
                ),
                .init(
                    title: "Ab",
                    url: "https://example.com/one.m3u8",
                    tvgLogo: "https://example.com/one.png",
                    tvgID: "1",
                    tvgName: nil,
                    groupTitle: "BB"
                ),
                .init(
                    title: "Cd",
                    url: "https://example.com/three.m3u8",
                    tvgLogo: nil,
                    tvgID: "3",
                    tvgName: nil,
                    groupTitle: "AA"
                ),
                .init(
                    title: "Ef",
                    url: "https://example.com/four.m3u8",
                    tvgLogo: nil,
                    tvgID: "4",
                    tvgName: nil,
                    groupTitle: nil
                )
            ]
        )
        
        let database = DatabaseService(isStoredInMemoryOnly: true)
        let settings = PlaylistSettingsItem(order: PlaylistSettingsItem.StreamListOrder.none.rawValue)
        let item = PlaylistItem(
            name: expectedContent.identity.name,
            date: expectedContent.identity.date, icon: nil, url: nil, data: nil,
            salt: nil, encrypted: false, settings: settings
        )
        database.mainContext.insert(item)
        try database.mainContext.save()
        Container.shared.databaseService.register { database }
        
        let service = MockPlaylistService(result: .success([playlist]))
        Container.shared.playlistService.register { service }
        let viewModel = PlaylistViewModel(content: expectedContent)

        await viewModel.loadStreams()

        #expect(service.requestedContent == expectedContent)
        #expect(viewModel.streams == [
            [
                .init(
                    title: "Bc",
                    url: "https://example.com/two.m3u8",
                    tvgLogo: nil,
                    tvgID: "2",
                    tvgName: nil,
                    groupTitle: "AA"
                ),
                .init(
                    title: "Cd",
                    url: "https://example.com/three.m3u8",
                    tvgLogo: nil,
                    tvgID: "3",
                    tvgName: nil,
                    groupTitle: "AA"
                ),
            ],
            [
                .init(
                    title: "Ab",
                    url: "https://example.com/one.m3u8",
                    tvgLogo: "https://example.com/one.png",
                    tvgID: "1",
                    tvgName: nil,
                    groupTitle: "BB"
                )
            ],
            [
                .init(
                    title: "Ef",
                    url: "https://example.com/four.m3u8",
                    tvgLogo: nil,
                    tvgID: "4",
                    tvgName: nil,
                    groupTitle: nil
                )
            ]
        ])
    }
    
    @Test func streamsAscOrder() async throws {
        let expectedContent = makeContent()
        let playlist = makePlaylist(
            streams: [
                .init(
                    title: "Bc",
                    url: "https://example.com/two.m3u8",
                    tvgLogo: nil,
                    tvgID: "2",
                    tvgName: nil,
                    groupTitle: nil
                ),
                .init(
                    title: "Ab",
                    url: "https://example.com/one.m3u8",
                    tvgLogo: "https://example.com/one.png",
                    tvgID: "1",
                    tvgName: nil,
                    groupTitle: nil
                ),
                .init(
                    title: "Cd",
                    url: "https://example.com/three.m3u8",
                    tvgLogo: nil,
                    tvgID: "3",
                    tvgName: nil,
                    groupTitle: nil
                )
            ]
        )
        
        let database = DatabaseService(isStoredInMemoryOnly: true)
        let settings = PlaylistSettingsItem(order: PlaylistSettingsItem.StreamListOrder.ascending.rawValue)
        let item = PlaylistItem(
            name: expectedContent.identity.name,
            date: expectedContent.identity.date, icon: nil, url: nil, data: nil,
            salt: nil, encrypted: false, settings: settings
        )
        database.mainContext.insert(item)
        try database.mainContext.save()
        Container.shared.databaseService.register { database }
        
        let service = MockPlaylistService(result: .success([playlist]))
        Container.shared.playlistService.register { service }
        let viewModel = PlaylistViewModel(content: expectedContent)

        await viewModel.loadStreams()

        #expect(service.requestedContent == expectedContent)
        #expect(viewModel.streams == [[
            .init(
                title: "Ab",
                url: "https://example.com/one.m3u8",
                tvgLogo: "https://example.com/one.png",
                tvgID: "1",
                tvgName: nil,
                groupTitle: nil
            ),
            .init(
                title: "Bc",
                url: "https://example.com/two.m3u8",
                tvgLogo: nil,
                tvgID: "2",
                tvgName: nil,
                groupTitle: nil
            ),
            .init(
                title: "Cd",
                url: "https://example.com/three.m3u8",
                tvgLogo: nil,
                tvgID: "3",
                tvgName: nil,
                groupTitle: nil
            )
        ]])
    }
    
    @Test func streamsDescOrder() async throws {
        let expectedContent = makeContent()
        let playlist = makePlaylist(
            streams: [
                .init(
                    title: "Bc",
                    url: "https://example.com/two.m3u8",
                    tvgLogo: nil,
                    tvgID: "2",
                    tvgName: nil,
                    groupTitle: "Abc"
                ),
                .init(
                    title: "Ab",
                    url: "https://example.com/one.m3u8",
                    tvgLogo: "https://example.com/one.png",
                    tvgID: "1",
                    tvgName: nil,
                    groupTitle: nil
                ),
                .init(
                    title: "Cd",
                    url: "https://example.com/three.m3u8",
                    tvgLogo: nil,
                    tvgID: "3",
                    tvgName: nil,
                    groupTitle: "Abc"
                )
            ]
        )
        
        let database = DatabaseService(isStoredInMemoryOnly: true)
        let settings = PlaylistSettingsItem(order: PlaylistSettingsItem.StreamListOrder.descending.rawValue)
        let item = PlaylistItem(
            name: expectedContent.identity.name,
            date: expectedContent.identity.date, icon: nil, url: nil, data: nil,
            salt: nil, encrypted: false, settings: settings
        )
        database.mainContext.insert(item)
        try database.mainContext.save()
        Container.shared.databaseService.register { database }
        
        let service = MockPlaylistService(result: .success([playlist]))
        Container.shared.playlistService.register { service }
        let viewModel = PlaylistViewModel(content: expectedContent)

        await viewModel.loadStreams()

        #expect(service.requestedContent == expectedContent)
        #expect(viewModel.streams == [[
            .init(
                title: "Cd",
                url: "https://example.com/three.m3u8",
                tvgLogo: nil,
                tvgID: "3",
                tvgName: nil,
                groupTitle: "Abc"
            ),
            .init(
                title: "Bc",
                url: "https://example.com/two.m3u8",
                tvgLogo: nil,
                tvgID: "2",
                tvgName: nil,
                groupTitle: "Abc"
            ),
            .init(
                title: "Ab",
                url: "https://example.com/one.m3u8",
                tvgLogo: "https://example.com/one.png",
                tvgID: "1",
                tvgName: nil,
                groupTitle: nil
            )
        ]])
    }
    
    @Test func streamsRecentOrder() async throws {
        let expectedContent = makeContent(url: "http://playlist.me")
        let playlist = makePlaylist(
            streams: [
                .init(
                    title: "De",
                    url: "https://example.com/forth.m3u8",
                    tvgLogo: nil,
                    tvgID: "4",
                    tvgName: nil,
                    groupTitle: "Abc"
                ),
                .init(
                    title: "Ef",
                    url: "https://example.com/fives.m3u8",
                    tvgLogo: nil,
                    tvgID: "5",
                    tvgName: nil,
                    groupTitle: "Abc"
                ),
                .init(
                    title: "Bc",
                    url: "https://example.com/two.m3u8",
                    tvgLogo: nil,
                    tvgID: "2",
                    tvgName: nil,
                    groupTitle: nil
                ),
                .init(
                    title: "Ab",
                    url: "https://example.com/one.m3u8",
                    tvgLogo: "https://example.com/one.png",
                    tvgID: "1",
                    tvgName: nil,
                    groupTitle: nil
                ),
                .init(
                    title: "Cd",
                    url: "https://example.com/three.m3u8",
                    tvgLogo: nil,
                    tvgID: "3",
                    tvgName: nil,
                    groupTitle: nil
                )
            ]
        )
        
        let database = DatabaseService(isStoredInMemoryOnly: true)
        let settings = PlaylistSettingsItem(order: PlaylistSettingsItem.StreamListOrder.recentViewed.rawValue)
        let item = PlaylistItem(
            name: expectedContent.identity.name,
            date: expectedContent.identity.date, icon: nil, url: nil, data: nil,
            salt: nil, encrypted: false, settings: settings
        )
        database.mainContext.insert(item)
        try database.mainContext.save()
        Container.shared.databaseService.register { database }
        
        let service = MockPlaylistService(result: .success([playlist]))
        Container.shared.playlistService.register { service }
        let viewModel = PlaylistViewModel(content: expectedContent)
        viewModel.selectedStream(playlist.streams[3])
        try await Task.sleep(for: .milliseconds(1))
        viewModel.selectedStream(playlist.streams[4])

        await viewModel.loadStreams()
        
        let expectedStreams: [[PlaylistParser.Stream]] = [[
            .init(
                title: "Cd",
                url: "https://example.com/three.m3u8",
                tvgLogo: nil,
                tvgID: "3",
                tvgName: nil,
                groupTitle: nil
            ),
            .init(
                title: "Ab",
                url: "https://example.com/one.m3u8",
                tvgLogo: "https://example.com/one.png",
                tvgID: "1",
                tvgName: nil,
                groupTitle: nil
            ),
            .init(
                title: "De",
                url: "https://example.com/forth.m3u8",
                tvgLogo: nil,
                tvgID: "4",
                tvgName: nil,
                groupTitle: "Abc"
            ),
            .init(
                title: "Ef",
                url: "https://example.com/fives.m3u8",
                tvgLogo: nil,
                tvgID: "5",
                tvgName: nil,
                groupTitle: "Abc"
            ),
            .init(
                title: "Bc",
                url: "https://example.com/two.m3u8",
                tvgLogo: nil,
                tvgID: "2",
                tvgName: nil,
                groupTitle: nil
            ),
        ]]

        #expect(service.requestedContent == expectedContent)
        #expect(viewModel.streams == expectedStreams)
        
        item.encrypted = true
        item.salt = Crypto.generateSalt()
        
        try database.mainContext.save()
        
        await viewModel.loadStreams()
        
        #expect(viewModel.streams == expectedStreams)
    }
    
    @Test func streamsMostOrder() async throws {
        let expectedContent = makeContent()
        let playlist = makePlaylist(
            streams: [
                .init(
                    title: "Bc",
                    url: "https://example.com/two.m3u8",
                    tvgLogo: nil,
                    tvgID: "2",
                    tvgName: nil,
                    groupTitle: "Abc"
                ),
                .init(
                    title: "Ab",
                    url: "https://example.com/one.m3u8",
                    tvgLogo: "https://example.com/one.png",
                    tvgID: "1",
                    tvgName: nil,
                    groupTitle: "Abc"
                ),
                .init(
                    title: "Cd",
                    url: "https://example.com/three.m3u8",
                    tvgLogo: nil,
                    tvgID: "3",
                    tvgName: nil,
                    groupTitle: nil
                ),
                .init(
                    title: "De",
                    url: "https://example.com/forth.m3u8",
                    tvgLogo: nil,
                    tvgID: "4",
                    tvgName: nil,
                    groupTitle: nil
                ),
                .init(
                    title: "Ef",
                    url: "https://example.com/fives.m3u8",
                    tvgLogo: nil,
                    tvgID: "5",
                    tvgName: nil,
                    groupTitle: nil
                )
            ]
        )
        
        let database = DatabaseService(isStoredInMemoryOnly: true)
        let settings = PlaylistSettingsItem(order: PlaylistSettingsItem.StreamListOrder.mostViewed.rawValue)
        let item = PlaylistItem(
            name: expectedContent.identity.name,
            date: expectedContent.identity.date, icon: nil, url: nil, data: nil,
            salt: nil, encrypted: false, settings: settings
        )
        database.mainContext.insert(item)
        try database.mainContext.save()
        Container.shared.databaseService.register { database }
        
        let service = MockPlaylistService(result: .success([playlist]))
        Container.shared.playlistService.register { service }
        let viewModel = PlaylistViewModel(content: expectedContent)
        viewModel.selectedStream(playlist.streams[1])
        try await Task.sleep(for: .milliseconds(1))
        viewModel.selectedStream(playlist.streams[0])
        
        try database.mainContext.save()
        
        let now = Date()
        #expect(item.settings?.views.count == 2)
        #expect(item.settings?.views["1tTtE3mj+o1VCjd5RC5GQExUo9Rl0OCGvlyMbeGPNiA="] == 1)
        #expect(item.settings?.views["+qGOTX85xIA8FhUXdnL0agBCYzFs/hKxp2lxYcmGKiI="] == 1)
        #expect(
            item.settings?.recent["+qGOTX85xIA8FhUXdnL0agBCYzFs/hKxp2lxYcmGKiI="] ?? now >
            item.settings?.recent["1tTtE3mj+o1VCjd5RC5GQExUo9Rl0OCGvlyMbeGPNiA="] ?? now)
        #expect(item.settings?.encrypted.count == 2)
        
        try await Task.sleep(for: .milliseconds(1))
        viewModel.selectedStream(playlist.streams[1])
        
        try database.mainContext.save()
        
        #expect(item.settings?.views.count == 2)
        #expect(item.settings?.views["+qGOTX85xIA8FhUXdnL0agBCYzFs/hKxp2lxYcmGKiI="] == 1)
        #expect(item.settings?.views["1tTtE3mj+o1VCjd5RC5GQExUo9Rl0OCGvlyMbeGPNiA="] == 2)
        #expect(
            item.settings?.recent["+qGOTX85xIA8FhUXdnL0agBCYzFs/hKxp2lxYcmGKiI="] ?? now <
            item.settings?.recent["1tTtE3mj+o1VCjd5RC5GQExUo9Rl0OCGvlyMbeGPNiA="] ?? now)
        #expect(item.settings?.recent.count == 2)
        #expect(item.settings?.encrypted.count == 2)

        await viewModel.loadStreams()

        let expectedStreams: [[PlaylistParser.Stream]] = [[
            .init(
                title: "Ab",
                url: "https://example.com/one.m3u8",
                tvgLogo: "https://example.com/one.png",
                tvgID: "1",
                tvgName: nil,
                groupTitle: "Abc"
            ),
            .init(
                title: "Bc",
                url: "https://example.com/two.m3u8",
                tvgLogo: nil,
                tvgID: "2",
                tvgName: nil,
                groupTitle: "Abc"
            ),
            .init(
                title: "Cd",
                url: "https://example.com/three.m3u8",
                tvgLogo: nil,
                tvgID: "3",
                tvgName: nil,
                groupTitle: nil
            ),
            .init(
                title: "De",
                url: "https://example.com/forth.m3u8",
                tvgLogo: nil,
                tvgID: "4",
                tvgName: nil,
                groupTitle: nil
            ),
            .init(
                title: "Ef",
                url: "https://example.com/fives.m3u8",
                tvgLogo: nil,
                tvgID: "5",
                tvgName: nil,
                groupTitle: nil
            )
        ]]
        
        #expect(service.requestedContent == expectedContent)
        #expect(viewModel.streams == expectedStreams)
        
        item.encrypted = true
        item.salt = Crypto.generateSalt()
        
        try database.mainContext.save()
        
        await viewModel.loadStreams()
        
        #expect(viewModel.streams == expectedStreams)
    }
}

private extension PlaylistViewModelTests {

    enum MockError: LocalizedError {
        case failed

        var errorDescription: String? {
            "Failed to load streams."
        }
    }

    func makeContent(url: String = "https://example.com/playlist.m3u") -> PlaylistItem.Content {
        PlaylistItem.Content(
            identity: .init(
                name: "Playlist",
                date: Date(timeIntervalSince1970: 1)
            ),
            url: Data(url.utf8),
            data: Data("#EXTM3U".utf8),
            isStoredInMemoryOnly: true
        )
    }

    func makePlaylist(
        streams: [PlaylistParser.Stream]
    ) -> PlaylistParser.Playlist {
        .init(
            tvgURL: nil,
            imageURL: nil,
            xTvgURL: nil,
            tvgLogo: nil,
            streams: streams
        )
    }
}

private final class MockPlaylistService: PlaylistServiceInterface, @unchecked Sendable {

    let result: Result<[PlaylistParser.Playlist], Error>
    let programGuide: ProgramGuide?
    private(set) var requestedContent: PlaylistItem.Content?
    private(set) var requestedReloadProgramGuide: Bool?

    init(result: Result<[PlaylistParser.Playlist], Error>, programGuide: ProgramGuide? = nil) {
        self.result = result
        self.programGuide = programGuide
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadProgramGuide: Bool,
        progress: @escaping ProgressHandler = { _, _ in}
    ) async throws -> [PlaylistParser.Playlist] {
        requestedContent = content
        requestedReloadProgramGuide = reloadProgramGuide
        return try result.get()
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadPlaylist: Bool,
        progress: @escaping ProgressHandler = { _, _ in}
    ) async throws -> [PlaylistParser.Playlist] {
        requestedContent = content
        return try result.get()
    }

    func programGuide(
        for content: PlaylistItem.Content,
        stream: PlaylistParser.Stream
    ) async -> ProgramGuide? {
        programGuide
    }

    func clearCache(for content: PlaylistItem.Content) async {
    }
    
    func programGuides(for content: PlaylistItem.Content, since: Date) async -> [ProgramGuide] {
        programGuide.map({ [$0] }).flatMap({ $0 }) ?? []
    }
}
