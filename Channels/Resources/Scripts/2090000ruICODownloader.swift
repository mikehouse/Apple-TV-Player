//
//  2090000ruICODownloader.swift
//  Channels
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import Foundation

private func download(path: String) {
    print("fetching content of \(path) ...")
    let htmlURL = URL(string: path)!
    do {
        let html = try String(contentsOf: htmlURL, encoding: .utf8)
        let lines = html.components(separatedBy: .newlines)
        var hashmap: [String: String] = [:]
        for (idx, line) in lines.enumerated() {
            if line.contains("upload/resize_cache/iblock") {
                var div = ""
                if line.contains("title=") {
                    div = line
                } else if lines[idx + 1].contains("title=") {
                    div = "\(line) \(lines[idx + 1])"
                } else if lines[idx + 2].contains("title=") {
                    div = "\(line) \(lines[idx + 1])  \(lines[idx + 2])"
                } else {
                    continue
                }
                
                let components = div.components(separatedBy: "\"")
                let image = "https://2090000.ru\(components[1])"
                let title = components[5]
                hashmap[image] = title
            }
        }
        
        let fileManager = FileManager.default
        let dir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        try hashmap.forEach { (arg0) in
            let (path, title) = arg0
            let url = URL(string: path)!
            print("---> downloading \(url.path)")
            let data = try Data(contentsOf: url)
            let dest = dir
                .appendingPathComponent(title, isDirectory: false)
                .appendingPathExtension(url.pathExtension)
            print("---> store to \(dest.path)")
            try data.write(to: dest, options: [.noFileProtection, .atomic])
        }
        print("\nopen Finder with command 'open \(dir.path)'")
    } catch {
        print(error)
    }
}

download(path: "https://2090000.ru/televidenie")
