//
//  TeleguideInfoParser.swift
//  Channels
//
//  Created by Mikhail Demidov on 22.01.2023.
//

import Foundation

private enum TBXMLClientError: Error {
    case parsingError
    case invalidRoot
    case missingChannelId
    case missingChannelDisplayName(channelId: String)
    case missingProgrammeChannelId
    case unknownProgrammeChannel(channelId: String)
    case missingProgrammeStart(channelId: String)
    case invalidProgrammeStart(channelId: String)
    case missingProgrammeStop(channelId: String)
    case invalidProgrammeStop(channelId: String)
    case missingProgrammeTitle(channelId: String)
}

private struct TBXMLClient {

    typealias Programme = ChannelProgramme.Programme

    let fromDate: Date
    let channelsOnly: Bool

    func parse(url: URL) throws -> [ChannelProgramme] {
        let data = try Data(contentsOf: url)
        let document: TBXML
        do {
            document = try TBXML.newTBXML(withXMLData: data, error: ())
        } catch {
            throw TBXMLClientError.parsingError
        }

        guard let root = document.rootXMLElement else {
            throw TBXMLClientError.invalidRoot
        }

        guard TBXML.elementName(root) == "tv" else {
            throw TBXMLClientError.invalidRoot
        }

        let channelElements = elements(named: "channel", parent: root)
        var channels: [ChannelOttclub] = []
        channels.reserveCapacity(channelElements.count)
        var channelsById: [String: ChannelOttclub] = [:]
        channelsById.reserveCapacity(channelElements.count)

        var channelsNameById: [String: String] = [:]
        channelsNameById.reserveCapacity(channelElements.count)

        for channelElement in channelElements {
            guard let channelId = attribute(named: "id", in: channelElement), !channelId.isEmpty else {
                throw TBXMLClientError.missingChannelId
            }

            let displayName = childText(named: "display-name", in: channelElement)
            guard !displayName.isEmpty else {
                throw TBXMLClientError.missingChannelDisplayName(channelId: channelId)
            }

            let icon = childAttribute(named: "icon", attribute: "src", in: channelElement)

            let channel = ChannelOttclub(name: displayName, stream: URL(fileURLWithPath: "/"),
                                         group: nil, logo: icon.flatMap({URL(string: $0)}))

            channels.append(channel)
            channelsById[channelId] = channel
            channelsNameById[displayName] = channelId
        }

        let programmeElements = elements(named: "programme", parent: root)
        var programmesByChannelId: [String: [Programme]] = [:]
        programmesByChannelId.reserveCapacity(channels.count)

        for programmeElement in programmeElements where !channelsOnly {
            guard let channelId = attribute(named: "channel", in: programmeElement), !channelId.isEmpty else {
                throw TBXMLClientError.missingProgrammeChannelId
            }

            guard channelsById[channelId] != nil else {
                throw TBXMLClientError.unknownProgrammeChannel(channelId: channelId)
            }

            guard let start = attribute(named: "start", in: programmeElement), !start.isEmpty else {
                throw TBXMLClientError.missingProgrammeStart(channelId: channelId)
            }

            guard let startDate = dateFormatter.date(from: start) else {
                throw TBXMLClientError.invalidProgrammeStart(channelId: channelId)
            }

            guard startDate >= fromDate else {
                continue
            }

            guard let stop = attribute(named: "stop", in: programmeElement), !stop.isEmpty else {
                throw TBXMLClientError.missingProgrammeStop(channelId: channelId)
            }

            guard let stopDate = dateFormatter.date(from: stop) else {
                throw TBXMLClientError.invalidProgrammeStop(channelId: channelId)
            }

            let title = childText(named: "title", in: programmeElement)
            guard !title.isEmpty else {
                throw TBXMLClientError.missingProgrammeTitle(channelId: channelId)
            }

            let programme = Programme(name: title, start: startDate, end: stopDate)
            programmesByChannelId[channelId, default: []].append(programme)
        }

        return channels.map { channel in
            ChannelProgramme(
                channel: channel,
                programmes: channelsNameById[channel.name].flatMap { programmesByChannelId[$0] } ?? []
            )
        }
    }
}

private func elements(named name: String, parent: UnsafeMutablePointer<TBXMLElement>) -> [UnsafeMutablePointer<TBXMLElement>] {
    var elements: [UnsafeMutablePointer<TBXMLElement>] = []
    var current = TBXML.childElementNamed(name, parentElement: parent)
    while let element = current {
        elements.append(element)
        current = TBXML.nextSiblingNamed(name, searchFrom: element)
    }
    return elements
}

private func attribute(named name: String, in element: UnsafeMutablePointer<TBXMLElement>) -> String? {
    TBXML.value(ofAttributeNamed: name, for: element)
}

private func childText(named name: String, in element: UnsafeMutablePointer<TBXMLElement>) -> String {
    guard let child = TBXML.childElementNamed(name, parentElement: element) else {
        return ""
    }

    let text = TBXML.text(for: child) ?? ""
    return text.replacingOccurrences(of: "&quot;", with: "")
}

private func childAttribute(named name: String, attribute: String, in element: UnsafeMutablePointer<TBXMLElement>) -> String? {
    guard let child = TBXML.childElementNamed(name, parentElement: element) else {
        return nil
    }

    return TBXML.value(ofAttributeNamed: attribute, for: child)
}

final class EgpParser: NSObject {

    let url: URL

    private var foundProgrammes: [ChannelProgramme] = []
    private var fromDate = Date()

    init(url: URL) {
        self.url = url
        super.init()
    }

    func channels() throws -> [Channel] {
        try TBXMLClient(fromDate: fromDate, channelsOnly: true).parse(url: url).map(\.channel)
    }

    func programme(from date: Date)  throws -> [ChannelProgramme] {
        if fromDate == date, foundProgrammes.isEmpty == false {
            return foundProgrammes
        }
        fromDate = date
        foundProgrammes = try TBXMLClient(fromDate: fromDate, channelsOnly: false).parse(url: url)
        for prog in foundProgrammes {
            prog.sortLastAtFirst()
        }
        return foundProgrammes
    }
}

private let dateFormatter = ManualDateFormatter()

private final class ManualDateFormatter {

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
