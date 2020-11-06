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
            let line = lines[i]
            guard line.hasPrefix(Directive.extinf.rawValue) else {
                continue
            }
            var tagStart = 0
            var tags: [NSRange] = []
            var skipSplit = true
            var skipSplit2 = false
            for (idx, ch) in line.enumerated() {
                if idx <= Directive.extinf.rawValue.count {
                    // skip prefix.
                    continue
                }
                if idx == line.count - 1 {
                    if tagStart != 0 && idx - tagStart != 1 {
                        tags.append(.init(
                            location: tagStart + 1,
                            length: idx - tagStart))
                    }
                    continue
                }
                if (ch == " ") {
                    if tagStart != 0 {
                        if skipSplit {
                            // case tag with white spaces.
                            continue
                        }
                        if idx - tagStart == 1 {
                            tagStart = idx
                            // case when two white spaces in row.
                        } else {
                            tags.append(.init(
                                location: tagStart + 1,
                                length: idx - tagStart))
                            tagStart = idx
                            skipSplit = true
                            skipSplit2 = false
                        }
                    } else {
                        tagStart = idx
                    }
                } else {
                    if ch == "=" {
                        skipSplit = false
                    } else if ch == "\"" {
                        if !skipSplit2 {
                            skipSplit2 = true
                            skipSplit = true
                        } else {
                            skipSplit = false
                        }
                    }
                }
            }
            var group: String?
            var title: String = NSLocalizedString("title not found.", comment: "")
            let nsstring = line as NSString
            for range in tags {
                let tag = nsstring.substring(with: range)
                if tag.contains(M3U.Directive.title.rawValue) {
                    group = tag.components(separatedBy: "=")[1]
                        .replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    group = group.map({ $0.trimmingCharacters(in: .whitespaces) })
                } else if !tag.contains("=") {
                    title = tag.trimmingCharacters(in: .whitespaces)
                }
            }
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
        case title = "group-title="
    }
}
