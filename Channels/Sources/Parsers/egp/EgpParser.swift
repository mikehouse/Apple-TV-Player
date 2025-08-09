//
//  TeleguideInfoParser.swift
//  Channels
//
//  Created by Mikhail Demidov on 22.01.2023.
//

import Foundation

final class EgpParser: NSObject {

    let url: URL

    private var parseMode = ParseMode.channel
    private var foundChannels: [ChannelOttclub] = []
    private var foundChannelsFastAccess: [String: ChannelOttclub] = [:]
    private var foundProgrammes: [ChannelProgramme] = []
    private var foundProgrammesFastAccess: [String: ChannelProgramme] = [:]
    private var parseError: Error?
    private var tmpChannel: TmpChannel?
    private var tmpProgramme: Programme?
    private var aborted = false
    private var fromDate = Date()

    init(url: URL) {
        self.url = url
        super.init()
    }

    func channels() throws -> [Channel] {
        guard foundChannels.isEmpty else {
            return foundChannels
        }
        parseMode = .channel
        try parse()
        return foundChannels
    }

    func programme(from date: Date)  throws -> [ChannelProgramme] {
        if fromDate == date, foundProgrammes.isEmpty == false {
            return foundProgrammes
        }
        fromDate = date
        parseMode = .programme
        try parse()
        for prog in foundProgrammes {
            prog.sortLastAtFirst()
        }
        return foundProgrammes
    }

    private func parse() throws {
        aborted = false

        logger.debug("start parse xml \(self.url.path)")
        if let parser = XMLParser(contentsOf: url) {
            parser.delegate = self
            parser.parse()
            parseError = parser.parserError
        } else {
            self.parseError = NSError(domain: "parser.file_read.error", code: -1, userInfo: [
                NSLocalizedDescriptionKey: url.path
            ])
        }
        if aborted == false, let parseError {
            throw parseError
        }
    }

    private enum ParseMode: Hashable {
        case channel
        case programme
    }

    private final class TmpChannel {
        var name: String?
        var id: String?
        var logo: String?
        var nameStartChars = false
    }

    private final class Programme {
        var start: String?
        var stop: String?
        var channel: String?
        var title: String?
        var titleStartCharts = false
    }
}

extension EgpParser: XMLParserDelegate {
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        if elementName == "channel" {
            tmpChannel = TmpChannel()
            tmpChannel?.id = attributeDict["id"]
        }
        if elementName == "icon" {
            tmpChannel?.logo = attributeDict["src"]
        }
        if elementName == "display-name" {
            tmpChannel?.nameStartChars = true
        }
        if elementName == "programme" {
            if parseMode == .channel {
                aborted = true
                parser.abortParsing()
            } else {
                tmpProgramme = Programme()
                tmpProgramme?.start = attributeDict["start"]
                tmpProgramme?.stop = attributeDict["stop"]
                tmpProgramme?.channel = attributeDict["channel"]
            }
        }
        if elementName == "title" {
            tmpProgramme?.titleStartCharts = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if tmpChannel?.nameStartChars == true {
            tmpChannel?.name = (tmpChannel?.name ?? "") + string
        }
        if tmpProgramme?.titleStartCharts == true {
            tmpProgramme?.title = (tmpProgramme?.title ?? "") + string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "display-name" {
            tmpChannel?.nameStartChars = false
        }
        if elementName == "channel" {
            if let name = tmpChannel?.name, let id = tmpChannel?.id {
                let channel = ChannelOttclub(name: name, stream: URL(fileURLWithPath: "/"),
                    group: nil, logo: tmpChannel?.logo.flatMap({URL(string: $0)}))
                foundChannels.append(channel)
                foundChannelsFastAccess[id] = channel
            }
            tmpChannel = nil
        }
        if elementName == "title" {
            tmpProgramme?.titleStartCharts = false
        }
        if elementName == "programme" {
            if let id = tmpProgramme?.channel,
               let channel =  foundChannelsFastAccess[id],
               let start = tmpProgramme?.start,
               let stop = tmpProgramme?.stop,
               let title = tmpProgramme?.title {
                if let start = dateFormatter.date(from: start),
                   start >= fromDate,
                   let stop = dateFormatter.date(from: stop) {
                    let programme: ChannelProgramme
                    if let cached = foundProgrammesFastAccess[id] {
                        programme = cached
                    } else {
                        programme = ChannelProgramme(channel: channel)
                        foundProgrammes.append(programme)
                        foundProgrammesFastAccess[id] = programme
                    }
                    programme.add(programme: .init(
                        name: title, start: start, end: stop))
                }
            }
            tmpProgramme = nil
        }
    }
}

private let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyyMMddHHmmss Z"
    return fmt
}()