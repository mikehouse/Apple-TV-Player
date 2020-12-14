//
//  2090000ruBundlesDownloader.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 13.12.2020.
//

import Foundation

private func download(path base: String) {
    print("fetching content of \(base) ...")
    let htmlURL = URL(string: base)!
    do {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let lines = html.components(separatedBy: .newlines)
        var titles: [String] = []
        var hashmap: [String: [String]] = [:]
        for line in lines {
            if line.contains("channel__item-title") {
                let title = line
                    .components(separatedBy: ">")[1]
                    .components(separatedBy: "<")[0]
                titles.append(title)
            }
        }
        for title in titles {
            let search = "ТВ ПАКЕТ \(title)"
            for (idx, line) in lines.enumerated() {
                if line.contains(search) {
                    var index = idx + 1
                    var divInRow = 0
                    var channels: [String] = []
                    while true {
                        if lines[index].contains("tabs__items-item__title") {
                            divInRow = 0
                            let channel = lines[index]
                                .components(separatedBy: ">")[1]
                                .components(separatedBy: "<")[0]
                            channels.append(channel)
                        } else {
                            if divInRow > 3 {
                                break
                            }
                            if lines[index].trimmingCharacters(in: .whitespaces) == "</div>" {
                                divInRow += 1
                            }
                        }
                        index += 1
                    }
                    hashmap[title] = channels
                    break
                }
            }
        }
        
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        
        for title in titles {
            let name = String(title[title.index(after: title.startIndex)..<title.index(before: title.endIndex)])
            guard let value = hashmap[title] else {
                continue
            }
            let file = root
                .appendingPathComponent(name, isDirectory: false)
                .appendingPathExtension("txt")
            try value.joined(separator: "\n").data(using: .utf8)!.write(to: file)
            print(([file.path] + value).joined(separator: "\n"))
            print("\n")
        }
        print("open '\(root.path)'")
    } catch {
        print(error)
    }
}

download(path: "https://2090000.ru/televidenie")

// Then move packages to packages' bundle.
