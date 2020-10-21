//
//  M3U.swift
//  Channels
//
//  Created by Mikhail Demidov on 20.10.2020.
//

import Foundation
import os

public final class M3U {
    public let url: URL
    private(set) public var items: [M3UItem] = []
    
    public init(url: URL) {
        self.url = url
    }
}

public extension M3U {
    @discardableResult
    func parse() throws -> [M3UItem] {
        if Thread.isMainThread {
            os_log(.info, "Non UI task called on UI thread.")
        }
        
        let string = try String(contentsOf: url)
        let lines = string.components(separatedBy: .newlines)
        guard let firstLine = lines.first else {
            let error = NSError(domain: "com.tv.player", code: -1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Invalid M3U file format.", comment: "")
            ])
            throw error
        }
        guard firstLine.components(separatedBy: .whitespaces)
                  .filter({ !$0.isEmpty }).first == Directive.extm3u.rawValue else {
            let error = NSError(domain: "com.tv.player", code: -1, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("Invalid M3U header.", comment: "")
            ])
            throw error
        }
        var i = 0;
        var items: [M3UItem] = []
        while (true) {
            guard i < lines.count else {
                break
            }
            defer {
                i += 1
            }
            let line: NSString = lines[i] as NSString
            guard line.hasPrefix(Directive.extinf.rawValue) else {
                continue
            }
            let start = line.range(of: "group-title=")
            let end = line.range(of: ",")
            var group: String?
            if start.location != NSNotFound, end.location != NSNotFound {
                group = line.substring(with: NSRange(
                    location: start.location + start.length + 1,
                    length: end.location - 2 - (start.location + start.length)))
            }
            let title = line.components(separatedBy: ",").last.map(Self.trimStart(of:))
                ?? NSLocalizedString("title not found.", comment: "")
            i += 1
            guard i < lines.count else {
                break
            }
            let http = lines[i].replacingOccurrences(of: " ", with: "")
            guard http.hasPrefix(Directive.http.rawValue),
                  let url = URL(string: http) else {
                continue
            }
            let item = M3UItem(title: title, url: url, group: group)
            items.append(item)
        }
        
        self.items = items
        return items
    }
}

private extension M3U {
    enum Directive: String {
        case extm3u = "#EXTM3U"
        case extinf = "#EXTINF"
        case http
        case title = "group-title"
    }
    
    static func trimStart(of string: String) -> String {
        guard !string.isEmpty else {
            return string
        }
        var i = 0
        while string[string.index(string.startIndex, offsetBy: i)..<string.index(string.startIndex, offsetBy: i + 1)] == " " {
            i += 1
        }
        return String(string[string.index(string.startIndex, offsetBy: i)...])
    }
}
