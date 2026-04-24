import FactoryKit
import Foundation
import Observation

@Observable
final class StreamViewModel {

    enum ProgramState: Equatable, Sendable {
        case past
        case now
        case future
    }

    struct DisplayProgram: Identifiable, Equatable, Sendable {
        let program: ProgramGuide.Program
        let state: ProgramState
        let text: String

        var id: String {
            "\(program.start.timeIntervalSince1970)-\(program.stop.timeIntervalSince1970)-\(program.title)"
        }
    }

    @ObservationIgnored @Injected(\.playlistService) private var playlistService
    @ObservationIgnored @Injected(\.logger) private var logger
    @ObservationIgnored private let timeFormatter: DateFormatter

    let content: PlaylistItem.Content
    let stream: PlaylistParser.Stream
    let title: String

    private(set) var programs: [ProgramGuide.Program] = []
    private(set) var displayProgram: [DisplayProgram] = []
    private(set) var originStreamCurrentProgram: DisplayProgram?

    init(
        content: PlaylistItem.Content,
        stream: PlaylistParser.Stream,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.content = content
        self.stream = stream
        title = Self.title(for: stream)

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        timeFormatter = formatter
    }

    func loadPrograms() async {
        _ = await loadPrograms(stream)
    }

    func loadPrograms(_ stream: PlaylistParser.Stream) async -> Bool {
        logger.info("Read program guide stream", private: stream.title)
        guard let guide = await playlistService.programGuide(for: content, stream: stream) else {
            programs = []
            return false
        }

        programs = guide.programs.sorted(by: { $0.start < $1.start })
        return !programs.isEmpty
    }

    func displayedPrograms(at now: Date, stream: PlaylistParser.Stream) {
        guard !programs.isEmpty else {
            displayProgram = []
            return
        }

        let previousPrograms = Array(programs.filter({ $0.stop <= now }).suffix(2))
        let currentProgram = programs.first(where: { isCurrent($0, at: now) })
        let futureWindowEnd = now.addingTimeInterval(24 * 60 * 60)
        let futurePrograms = programs.filter {
            $0.start > now && $0.start < futureWindowEnd
        }
        guard let currentProgram else {
            displayProgram = []
            return
        }
        if stream == self.stream {
            self.originStreamCurrentProgram = .init(
                program: currentProgram,
                state: programState(for: currentProgram, at: now),
                text: formattedText(for: currentProgram)
            )
        }
        displayProgram = (previousPrograms + [currentProgram].compactMap({ $0 }) + futurePrograms).map {
            DisplayProgram(
                program: $0,
                state: programState(for: $0, at: now),
                text: formattedText(for: $0)
            )
        }
    }

    func currentTimeText(at now: Date) -> String {
        timeFormatter.string(from: now)
    }

    func programState(
        for program: ProgramGuide.Program,
        at now: Date
    ) -> ProgramState {
        if program.stop <= now {
            return .past
        }

        if isCurrent(program, at: now) {
            return .now
        }

        return .future
    }

    func formattedText(for program: ProgramGuide.Program) -> String {
        "\(timeFormatter.string(from: program.start)) - \(timeFormatter.string(from: program.stop)): \(program.title)"
    }

    isolated deinit {
        logger.info("deinit of \(self)")
    }
}

private extension StreamViewModel {

    func isCurrent(_ program: ProgramGuide.Program, at now: Date) -> Bool {
        program.start <= now && now < program.stop
    }

    static func title(for stream: PlaylistParser.Stream) -> String {
        let tvgName = stream.tvgName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (tvgName?.isEmpty == false ? tvgName : nil) ?? stream.title
    }
}
