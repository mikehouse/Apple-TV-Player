import FactoryKit
import FactoryTesting
import Foundation
import Observation
import os
import SwiftData
import Testing
@testable import Bro_Player

@Suite(.container)
struct StreamViewModelTests {

    @Test func initializationExposesInputsAndFallsBackToTitleForBlankTvgName() {
        let content = makeContent()
        let stream = makeStream(
            title: "Fallback",
            url: "https://example.com/fallback.m3u8",
            tvgName: " \n "
        )

        let viewModel = makeViewModel(content: content, stream: stream)

        #expect(viewModel.content == content)
        #expect(viewModel.stream == stream)
        #expect(viewModel.title == "Fallback")
    }

    @Test func displayProgramInitializesValuesAndUsesProgramIdentity() {
        let program = ProgramGuide.Program(
            title: "News",
            start: Date(timeIntervalSince1970: 100),
            stop: Date(timeIntervalSince1970: 200)
        )

        let displayProgram = StreamViewModel.DisplayProgram(
            program: program,
            state: .now,
            text: "News is on"
        )
        let updatedPresentation = StreamViewModel.DisplayProgram(
            program: program,
            state: .future,
            text: "News is next"
        )

        #expect(displayProgram.program == program)
        #expect(displayProgram.state == .now)
        #expect(displayProgram.text == "News is on")
        #expect(displayProgram.id == "100.0-200.0-News")
        #expect(updatedPresentation.id == displayProgram.id)
    }

    @Test func loadProgramsForSelectedStreamReturnsWhetherProgramsAreAvailable() async {
        let content = makeContent()
        let originStream = makeStream(title: "Origin", url: "https://example.com/origin.m3u8")
        let populatedStream = makeStream(title: "Populated", url: "https://example.com/populated.m3u8")
        let missingStream = makeStream(title: "Missing", url: "https://example.com/missing.m3u8")
        let emptyStream = makeStream(title: "Empty", url: "https://example.com/empty.m3u8")
        let program = makeProgram(
            title: "Program",
            startHour: 12,
            startMinute: 0,
            stopHour: 13,
            stopMinute: 0
        )
        let service = MockStreamPlaylistService(
            guides: [
                populatedStream: makeGuide(programs: [program]),
                emptyStream: makeGuide(programs: [])
            ]
        )
        Container.shared.playlistService.register { service }
        let viewModel = makeViewModel(content: content, stream: originStream)

        let populated = await viewModel.loadPrograms(populatedStream)

        #expect(populated)
        #expect(viewModel.programs == [program])

        let missing = await viewModel.loadPrograms(missingStream)

        #expect(!missing)
        #expect(viewModel.programs.isEmpty)

        let empty = await viewModel.loadPrograms(emptyStream)

        #expect(!empty)
        #expect(viewModel.programs.isEmpty)
        #expect(service.requestedContents == [content, content, content])
        #expect(service.requestedStreams == [populatedStream, missingStream, emptyStream])
    }

    @Test func displayedProgramsClearsPreviouslyDisplayedProgramsWhenNoProgramIsCurrent() async {
        let stream = makeStream()
        let service = MockStreamPlaylistService(
            guides: [
                stream: makeGuide(
                    programs: [
                        makeProgram(
                            title: "Current",
                            startHour: 11,
                            startMinute: 30,
                            stopHour: 12,
                            stopMinute: 30
                        )
                    ]
                )
            ]
        )
        Container.shared.playlistService.register { service }
        let viewModel = makeViewModel(stream: stream)
        await viewModel.loadPrograms()
        viewModel.displayedPrograms(
            at: date(day: 1, hour: 12, minute: 0),
            stream: stream
        )
        #expect(!viewModel.displayProgram.isEmpty)

        viewModel.displayedPrograms(
            at: date(day: 1, hour: 13, minute: 0),
            stream: stream
        )

        #expect(viewModel.displayProgram.isEmpty)
    }

    @Test func displayedProgramsUpdatesCurrentProgramOnlyForOriginStream() async throws {
        let originStream = makeStream(title: "Origin", url: "https://example.com/origin.m3u8")
        let alternateStream = makeStream(title: "Alternate", url: "https://example.com/alternate.m3u8")
        let originProgram = makeProgram(
            title: "Origin Program",
            startHour: 11,
            startMinute: 30,
            stopHour: 12,
            stopMinute: 30
        )
        let alternateProgram = makeProgram(
            title: "Alternate Program",
            startHour: 11,
            startMinute: 0,
            stopHour: 13,
            stopMinute: 0
        )
        let service = MockStreamPlaylistService(
            guides: [
                originStream: makeGuide(programs: [originProgram]),
                alternateStream: makeGuide(programs: [alternateProgram])
            ]
        )
        Container.shared.playlistService.register { service }
        let viewModel = makeViewModel(stream: originStream)
        let now = date(day: 1, hour: 12, minute: 0)

        await viewModel.loadPrograms()
        viewModel.displayedPrograms(at: now, stream: originStream)
        let originDisplayProgram = try #require(viewModel.originStreamCurrentProgram)

        #expect(originDisplayProgram.program == originProgram)
        #expect(originDisplayProgram.state == .now)
        #expect(originDisplayProgram.text == "11:30 - 12:30: Origin Program")

        _ = await viewModel.loadPrograms(alternateStream)
        viewModel.displayedPrograms(at: now, stream: alternateStream)

        #expect(viewModel.displayProgram.map(\.program) == [alternateProgram])
        #expect(viewModel.originStreamCurrentProgram == originDisplayProgram)
    }

    @Test func programStateUsesStartInclusiveStopExclusiveInterval() {
        let viewModel = makeViewModel()
        let program = ProgramGuide.Program(
            title: "Program",
            start: Date(timeIntervalSince1970: 100),
            stop: Date(timeIntervalSince1970: 200)
        )

        #expect(
            viewModel.programState(
                for: program,
                at: Date(timeIntervalSince1970: 99)
            ) == .future
        )
        #expect(
            viewModel.programState(
                for: program,
                at: Date(timeIntervalSince1970: 100)
            ) == .now
        )
        #expect(
            viewModel.programState(
                for: program,
                at: Date(timeIntervalSince1970: 199.999)
            ) == .now
        )
        #expect(
            viewModel.programState(
                for: program,
                at: Date(timeIntervalSince1970: 200)
            ) == .past
        )
    }

    @Test func repeatedEquivalentDisplayDoesNotNotifyObservers() async {
        let stream = makeStream()
        let service = MockStreamPlaylistService(
            guides: [
                stream: makeGuide(
                    programs: [
                        makeProgram(
                            title: "Current",
                            startHour: 11,
                            startMinute: 30,
                            stopHour: 12,
                            stopMinute: 30
                        )
                    ]
                )
            ]
        )
        Container.shared.playlistService.register { service }
        let viewModel = makeViewModel(stream: stream)
        let now = date(day: 1, hour: 12, minute: 0)
        await viewModel.loadPrograms()
        viewModel.displayedPrograms(at: now, stream: stream)
        let originalDisplay = viewModel.displayProgram
        let recorder = ObservationChangeRecorder()
        _ = withObservationTracking {
            viewModel.displayProgram
        } onChange: {
            recorder.recordChange()
        }

        viewModel.displayedPrograms(at: now, stream: stream)

        #expect(!recorder.didChange)
        #expect(viewModel.displayProgram == originalDisplay)

        viewModel.displayedPrograms(
            at: date(day: 1, hour: 13, minute: 0),
            stream: stream
        )

        #expect(recorder.didChange)
    }

#if os(iOS)
    @Test func pictureInPictureEnabledDefaultsToTrueWhenSettingsAreMissing() {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        Container.shared.databaseService.register { database }
        let viewModel = makeViewModel()

        #expect(viewModel.pictureInPictureEnabled == true)
    }

    @Test func pictureInPictureEnabledUsesStoredSetting() throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        database.mainContext.insert(
            AppSettings(iOSPictureInPictureEnabled: false)
        )
        try database.mainContext.save()
        Container.shared.databaseService.register { database }
        let viewModel = makeViewModel()

        #expect(viewModel.pictureInPictureEnabled == false)
    }
#endif
}

private extension StreamViewModelTests {

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    var timeZone: TimeZone {
        TimeZone(secondsFromGMT: 0)!
    }

    var locale: Locale {
        Locale(identifier: "en_US_POSIX")
    }

    func makeViewModel(
        content: PlaylistItem.Content? = nil,
        stream: PlaylistParser.Stream? = nil
    ) -> StreamViewModel {
        StreamViewModel(
            content: content ?? makeContent(),
            stream: stream ?? makeStream(),
            timeZone: timeZone,
            locale: locale
        )
    }

    func makeContent() -> PlaylistItem.Content {
        PlaylistItem.Content(
            identity: .init(
                name: "Playlist",
                date: Date(timeIntervalSince1970: 1)
            ),
            url: Data(),
            data: Data(),
            isStoredInMemoryOnly: true
        )
    }

    func makeStream(
        title: String = "Stream",
        url: String = "https://example.com/stream.m3u8",
        tvgName: String? = nil
    ) -> PlaylistParser.Stream {
        PlaylistParser.Stream(
            title: title,
            url: url,
            tvgLogo: nil,
            tvgID: nil,
            tvgName: tvgName,
            groupTitle: nil
        )
    }

    func makeGuide(programs: [ProgramGuide.Program]) -> ProgramGuide {
        ProgramGuide(
            channel: .init(
                id: "channel",
                displayName: "Stream",
                iconURL: nil
            ),
            programs: programs
        )
    }

    func makeProgram(
        title: String,
        day: Int = 1,
        startHour: Int,
        startMinute: Int,
        stopHour: Int,
        stopMinute: Int
    ) -> ProgramGuide.Program {
        ProgramGuide.Program(
            title: title,
            start: date(day: day, hour: startHour, minute: startMinute),
            stop: date(day: day, hour: stopHour, minute: stopMinute)
        )
    }

    func date(day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(
            from: DateComponents(
                year: 2026,
                month: 1,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}

private final class MockStreamPlaylistService: PlaylistServiceInterface, @unchecked Sendable {

    let guides: [PlaylistParser.Stream: ProgramGuide]
    private(set) var requestedContents: [PlaylistItem.Content] = []
    private(set) var requestedStreams: [PlaylistParser.Stream] = []

    init(guides: [PlaylistParser.Stream: ProgramGuide]) {
        self.guides = guides
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadProgramGuide: Bool,
        progress: @escaping ProgressHandler
    ) async throws -> [PlaylistParser.Playlist] {
        []
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadPlaylist: Bool,
        progress: @escaping ProgressHandler
    ) async throws -> [PlaylistParser.Playlist] {
        []
    }

    func programGuide(
        for content: PlaylistItem.Content,
        stream: PlaylistParser.Stream
    ) async -> ProgramGuide? {
        requestedContents.append(content)
        requestedStreams.append(stream)
        return guides[stream]
    }

    func programGuides(
        for content: PlaylistItem.Content,
        since: Date
    ) async -> [ProgramGuide] {
        []
    }

    func clearCache(for content: PlaylistItem.Content) async {
    }
}

private nonisolated final class ObservationChangeRecorder: Sendable {

    private let lock = OSAllocatedUnfairLock(initialState: false)

    var didChange: Bool {
        lock.withLock { $0 }
    }

    func recordChange() {
        lock.withLock { $0 = true }
    }
}
