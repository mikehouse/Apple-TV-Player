//
//  ProgrammesFetcher2090000.swift
//  Channels
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import Foundation
import os

internal final class ProgrammesFetcher2090000: IpTvProgrammesProvider {
    private var completion: ((Error?) -> Void)?
    private lazy var timer = Timer(timeInterval: 60 * 30, repeats: true) { [weak self] timer in
        if self == nil {
            timer.invalidate()
        } else {
            let _ = self?.completion.flatMap({ self?.load($0) })
        }
    }
    
    func load(_ completion: @escaping (Error?) -> Void) {
        let first = self.completion == nil
        self.completion = completion
        
        DispatchQueue.main.async {
            if first {
                RunLoop.current.add(self.timer, forMode: .default)
            }
            DispatchQueue.global(qos: .userInteractive).async {
                self.fetch()
            }
        }
    }
    
    func list(for channel: Channel) -> [String] {
        Self.cache[channel.name]
            ?? Self.aliases[channel.name].flatMap({ Self.cache[$0] })
            ?? Self.empty
    }
}

private extension ProgrammesFetcher2090000 {
    func fetch() {
        let base = "https://2090000.ru/programma-peredach"
        os_log(.info, "fetching content of \(base) ...")
        let htmlURL = URL(string: base)!
        do {
            let html = try String(contentsOf: htmlURL, encoding: .utf8)
            let lines = html.components(separatedBy: .newlines)
            main: for (idx, line) in lines.enumerated() {
                if line.contains("<h5>") {
                    var channel = ""
                    var counter = 0;
                    while true {
                        counter += 1
                        if lines[idx - counter].contains("title=") {
                            channel = lines[idx - counter]
                                .components(separatedBy: "title=")[1]
                                .components(separatedBy: "\"")[1]
                            break
                        } else if counter >= 3 {
                            break main
                        }
                    }
                    
                    counter = 0
                    var list: [String] = []
                    while true {
                        counter += 1
                        if lines[idx + counter].contains("program__channel-time") {
                            var time = ""
                            var name = ""
                            time = lines[idx + counter]
                                .components(separatedBy: ">")[1]
                                .components(separatedBy: "<")[0]
                            counter += 1
                            if lines[idx + counter].contains("program__channel-name") {
                                name = lines[idx + counter]
                                    .components(separatedBy: ">")[1]
                                    .components(separatedBy: "<")[0]
                                counter += 1
                                list.append("\(time) \(name)")
                                if lines[idx + counter + 2].trimmingCharacters(in: .whitespaces) == "</div>" {
                                    break
                                }
                            }
                        }
                    }
                    if !list.isEmpty {
                        Self.cache[channel] = list
                    }
                }
            }
            self.completion?(nil)
        } catch {
            os_log(.error, "\(error as NSObject)")
            self.completion?(error)
        }
    }
}

private extension ProgrammesFetcher2090000 {
    private static let empty: [String] = []
    private static var cache: [String: [String]] = [:]
    private static let aliases: [String: String] = [
        "Живи": "Живи HD",
        "Первый": "Первый HD",
        "TV1000": "TV 1000 HD",
        "Русский роман": "Русский роман HD",
        "Наша Сибирь HD": "Наша Сибирь 4К",
        "Кино ТВ HD": "Кино ТВ",
    ]
}
