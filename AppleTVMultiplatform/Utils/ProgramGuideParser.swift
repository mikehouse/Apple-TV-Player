import Foundation
import Kanna
import FactoryKit

nonisolated struct ProgramGuide: Equatable, Sendable {
    let channel: Channel
    let programs: [Program]
    
    nonisolated struct Channel: Equatable, Sendable {
        let id: String
        let displayName: String
        let iconURL: String?
    }
    
    nonisolated struct Program: Equatable, Sendable {
        let title: String
        let start: Date
        let stop: Date
    }
}

actor ProgramGuideParser {

    enum ParserError: Error, Equatable {
        case missingXMLFile
        case invalidXML
        case downloadFailed(Int)
    }

    enum Progress: String, Hashable, CaseIterable, Sendable {
        case start
        case downloading
        case unarchiving
        case parsing
        case complete
    }
    
    private func set(step: Unarchiver.Progress) {
        switch step {
        case .start:
            progress = .start
        case .downloading:
            progress = .downloading
        case .unarchiving:
            progress = .unarchiving
        default:
            break
        }
    }
    
    private func set(steps: [Unarchiver.Progress]) {
        guard self.progressSteps.isEmpty else {
            return
        }
        self.progressSteps = steps.map({ step -> [Progress] in
            switch step {
            case .start: return [.start]
            case .downloading: return [.downloading]
            case .unarchiving: return [.unarchiving, .parsing]
            case .complete: return [.complete]
            }
        }).flatMap({ $0 })
    }

    private let fileManager = FileManager.default
    @ObservationIgnored @Injected(\.logger) private var logger
    private lazy var unarchiver: Unarchiver = .init(onProgress: { [weak self] steps, step, unarchiver in
        guard let self = self else { return }
        Task {
            await self.set(steps: steps)
            await self.set(step: step)
        }
    })
    private let dateFormatter = ManualDateFormatter()
    private let onProgress: @Sendable ([Progress], Progress, isolated ProgramGuideParser) -> Void
    private var progressSteps: [Progress] = []
    private var progress: Progress = .start {
        didSet {
            onProgress(progressSteps, progress, self)
            if progress == .complete {
                progressSteps = []
            }
        }
    }

    init(onProgress: @Sendable @escaping ([Progress], Progress, isolated ProgramGuideParser) -> Void = { _, _, _ in }) {
        self.onProgress = onProgress
    }

    func parse(archiveURL: URL) async throws -> [ProgramGuide] {
        defer { progress = .complete }
        let extractedURLs = try await unarchiver.unarchive(archiveURL.absoluteString)
        defer { cleanupExtraction(at: extractedURLs) }

        let xmlURL = try xmlFileURL(from: extractedURLs)
        return try await parse(xmlURL: xmlURL)
    }

    func parse(xmlURL: URL) async throws -> [ProgramGuide] {
        var needsComplete = false
        if progress == .start {
            progressSteps = [.start, .parsing, .complete]
            needsComplete = true
            progress = .start
        }
        progress = .parsing
        defer { if needsComplete { progress = .complete } }
        let xmlString = try await loadXMLString(from: xmlURL)
        let result = try parse(xmlString: xmlString)
        return result
    }
}

private extension ProgramGuideParser {

    private func loadXMLString(from url: URL) async throws -> String {
        let data = try await loadData(from: url)

        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw ParserError.invalidXML
        }

        return xmlString
    }

    private func loadData(from url: URL) async throws -> Data {
        let measure = try await measureTime {
            try await _loadData(from: url)
        }
        logger.info("Program Guide loading completed in \(measure.milliseconds) milliseconds", private: url.absoluteString)
        return measure.result
    }

    private func _loadData(from url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200 ... 299).contains(httpResponse.statusCode) {
            throw ParserError.downloadFailed(httpResponse.statusCode)
        }

        return data
    }

    private func parse(xmlString: String) throws -> [ProgramGuide] {
        let measure = try measureTime {
            try _parse(xmlString: xmlString)
        }
        logger.info("Program Guide parsing completed in \(measure.milliseconds) milliseconds")
        return measure.result
    }

    private func _parse(xmlString: String) throws -> [ProgramGuide] {
        do {
            let document = try Kanna.XML(xml: xmlString, encoding: .utf8)

            var channelOrder: [String] = []
            var channelsByID: [String: ProgramGuide.Channel] = [:]

            for channelNode in document.xpath("/tv/channel") {
                guard
                    let channelID = normalized(channelNode["id"]),
                    let displayName = normalized(channelNode.at_xpath("display-name")?.text)
                else {
                    continue
                }

                if channelsByID[channelID] == nil {
                    channelOrder.append(channelID)
                }

                channelsByID[channelID] = .init(
                    id: channelID,
                    displayName: displayName,
                    iconURL: normalized(channelNode.at_xpath("icon")?["src"])
                )
            }

            var programsByChannelID: [String: [ProgramGuide.Program]] = [:]

            for programNode in document.xpath("/tv/programme") {
                guard
                    let channelID = normalized(programNode["channel"]),
                    let title = normalized(programNode.at_xpath("title")?.text),
                    let startValue = normalized(programNode["start"]),
                    let stopValue = normalized(programNode["stop"]),
                    let startDate = dateFormatter.date(from: startValue),
                    let stopDate = dateFormatter.date(from: stopValue)
                else {
                    continue
                }

                programsByChannelID[channelID, default: []].append(
                    .init(
                        title: title,
                        start: startDate,
                        stop: stopDate
                    )
                )
            }

            return channelOrder.compactMap { channelID in
                guard let channel = channelsByID[channelID] else {
                    return nil
                }

                return ProgramGuide(
                    channel: channel,
                    programs: programsByChannelID[channelID] ?? []
                )
            }
        } catch {
            logger.error(error)
            throw ParserError.invalidXML
        }
    }

    private func xmlFileURL(from extractedURLs: [URL]) throws -> URL {
        guard let xmlURL = extractedURLs.first(where: { $0.pathExtension.lowercased() == "xml" }) else {
            throw ParserError.missingXMLFile
        }

        return xmlURL
    }

    private func cleanupExtraction(at extractedURLs: [URL]) {
        let roots = Set(extractedURLs.compactMap(extractionRoot(for:)))

        for root in roots {
            try? fileManager.removeItem(at: root)
        }
    }

    private func extractionRoot(for extractedURL: URL) -> URL? {
        var currentURL = extractedURL

        while currentURL.path != "/" {
            if currentURL.lastPathComponent.hasPrefix("Unarchiver-") {
                return currentURL
            }

            currentURL.deleteLastPathComponent()
        }

        return nil
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }
}

nonisolated private struct ManualDateFormatter {

    func date(from string: String) -> Date? {
        // Format: "20260218135322 +0000"
        // Positions: YYYYMMDDHHMMSS +HHMM
        guard string.count >= 14 else { return nil }
        
        let yearStart = string.startIndex
        let yearEnd = string.index(yearStart, offsetBy: 4)
        let monthEnd = string.index(yearEnd, offsetBy: 2)
        let dayEnd = string.index(monthEnd, offsetBy: 2)
        let hourEnd = string.index(dayEnd, offsetBy: 2)
        let minuteEnd = string.index(hourEnd, offsetBy: 2)
        let secondEnd = string.index(minuteEnd, offsetBy: 2)
        
        guard let year = Int(string[yearStart..<yearEnd]),
              let month = Int(string[yearEnd..<monthEnd]),
              let day = Int(string[monthEnd..<dayEnd]),
              let hour = Int(string[dayEnd..<hourEnd]),
              let minute = Int(string[hourEnd..<minuteEnd]),
              let second = Int(string[minuteEnd..<secondEnd]) else {
            return nil
        }
        
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(secondsFromGMT: 0)
        
        return Calendar.current.date(from: components)
    }
}
