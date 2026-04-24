import FactoryKit
import FactoryTesting
import Foundation
import Testing
@testable import Bro_Player

@Suite(.container)
struct ProgramGuideViewModelTests {

    @Test func loadProgramsUsesServiceSortsProgramsAndPrefersTvgName() async throws {
        let content = makeContent()
        let stream = makeStream(title: "Fallback", tvgName: " Preferred ")
        let guide = ProgramGuide(
            channel: .init(id: "channel", displayName: "Preferred", iconURL: nil),
            programs: [
                makeProgram(title: "Later", startHour: 13, startMinute: 0, stopHour: 13, stopMinute: 30),
                makeProgram(title: "Earlier", startHour: 11, startMinute: 0, stopHour: 11, stopMinute: 30)
            ]
        )
        let service = MockProgramGuidePlaylistService(guide: guide)
        Container.shared.playlistService.register { service }
        let viewModel = StreamViewModel(
            content: content,
            stream: stream,
            timeZone: timeZone,
            locale: locale
        )

        await viewModel.loadPrograms()

        #expect(service.requestedContent == content)
        #expect(service.requestedStream == stream)
        #expect(viewModel.title == "Preferred")
        #expect(viewModel.programs.map(\.title) == ["Earlier", "Later"])
    }

    @Test func displayedProgramsKeepsFivePastCurrentAndNextTwentyFourHours() async throws {
        let now = date(day: 1, hour: 12, minute: 0)
        let stream = makeStream(title: "Guide", tvgName: nil)
        let guide = ProgramGuide(
            channel: .init(id: "channel", displayName: "Guide", iconURL: nil),
            programs: [
                makeProgram(title: "Past 1", day: 1, startHour: 7, startMinute: 0, stopHour: 7, stopMinute: 30),
                makeProgram(title: "Past 2", day: 1, startHour: 7, startMinute: 30, stopHour: 8, stopMinute: 0),
                makeProgram(title: "Past 3", day: 1, startHour: 8, startMinute: 0, stopHour: 8, stopMinute: 30),
                makeProgram(title: "Past 4", day: 1, startHour: 8, startMinute: 30, stopHour: 9, stopMinute: 0),
                makeProgram(title: "Past 5", day: 1, startHour: 9, startMinute: 0, stopHour: 9, stopMinute: 30),
                makeProgram(title: "Past 6", day: 1, startHour: 9, startMinute: 30, stopHour: 10, stopMinute: 0),
                makeProgram(title: "Past 7", day: 1, startHour: 10, startMinute: 0, stopHour: 10, stopMinute: 30),
                makeProgram(title: "Current", day: 1, startHour: 11, startMinute: 30, stopHour: 12, stopMinute: 30),
                makeProgram(title: "Future 1", day: 1, startHour: 12, startMinute: 30, stopHour: 13, stopMinute: 0),
                makeProgram(title: "Future 2", day: 2, startHour: 11, startMinute: 0, stopHour: 11, stopMinute: 30),
                makeProgram(title: "Future 3", day: 2, startHour: 12, startMinute: 30, stopHour: 13, stopMinute: 0)
            ]
        )
        let service = MockProgramGuidePlaylistService(guide: guide)
        Container.shared.playlistService.register { service }
        let viewModel = StreamViewModel(
            content: makeContent(),
            stream: stream,
            timeZone: timeZone,
            locale: locale
        )

        await viewModel.loadPrograms()
        viewModel.displayedPrograms(at: now, stream: stream)
        let displayedPrograms = viewModel.displayProgram

        #expect(displayedPrograms.map({ $0.program.title }) == [
            "Past 6",
            "Past 7",
            "Current",
            "Future 1",
            "Future 2"
        ])
        #expect(displayedPrograms.first?.state == .past)
        #expect(displayedPrograms[2].state == .now)
        #expect(displayedPrograms.last?.state == .future)
        #expect(displayedPrograms.first?.text == "09:30 - 10:00: Past 6")
        #expect(displayedPrograms[2].text == "11:30 - 12:30: Current")
        #expect(displayedPrograms.last?.text == "11:00 - 11:30: Future 2")
        #expect(viewModel.currentTimeText(at: now) == "12:00")
    }

    @Test func loadProgramsClearsProgramsWhenGuideIsMissing() async throws {
        let service = MockProgramGuidePlaylistService(guide: nil)
        Container.shared.playlistService.register { service }
        let viewModel = StreamViewModel(
            content: makeContent(),
            stream: makeStream(title: "Fallback", tvgName: nil),
            timeZone: timeZone,
            locale: locale
        )

        await viewModel.loadPrograms()

        #expect(viewModel.programs.isEmpty)
        viewModel.displayedPrograms(at: date(day: 1, hour: 12, minute: 0), stream: viewModel.stream)
        #expect(viewModel.displayProgram.isEmpty)
    }
}

private extension ProgramGuideViewModelTests {

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

    func makeContent() -> PlaylistItem.Content {
        PlaylistItem.Content(
            identity: .init(
                name: "Playlist",
                date: Date(timeIntervalSince1970: 1)
            ),
            url: Data("https://example.com/playlist.m3u".utf8),
            data: Data("#EXTM3U".utf8),
            isStoredInMemoryOnly: true
        )
    }

    func makeStream(title: String, tvgName: String?) -> PlaylistParser.Stream {
        .init(
            title: title,
            url: "https://example.com/stream.m3u8",
            tvgLogo: nil,
            tvgID: nil,
            tvgName: tvgName,
            groupTitle: nil
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
        .init(
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

private final class MockProgramGuidePlaylistService: PlaylistServiceInterface, @unchecked Sendable {

    let guide: ProgramGuide?
    private(set) var requestedContent: PlaylistItem.Content?
    private(set) var requestedStream: PlaylistParser.Stream?

    init(guide: ProgramGuide?) {
        self.guide = guide
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
        requestedContent = content
        requestedStream = stream
        return guide
    }

    func clearCache(for content: PlaylistItem.Content) async {
    }
    
    func programGuides(for content: PlaylistItem.Content, since: Date) async -> [ProgramGuide] {
        []
    }
}
