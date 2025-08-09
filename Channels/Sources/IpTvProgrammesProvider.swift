//
//  IpTvProgrammesProvider.swift
//  Channels
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import Foundation

public class ChannelProgramme {
    public let channel: Channel
    public private(set) var programmes: [Programme]

    public init(channel: Channel, programmes: [Programme]) {
        self.channel = channel
        self.programmes = programmes
    }

    public convenience init(channel: Channel) {
        self.init(channel: channel, programmes: [])
    }

    func add(programme: Programme) {
        programmes.append(programme)
    }

    func sortLastAtFirst() {
        programmes.sort(by: { $0.start < $1.start })
    }

    public class Programme {
        public let name: String
        public let start: Date
        public let end: Date

        public init(name: String, start: Date, end: Date) {
            self.name = name
            self.start = start
            self.end = end
        }
    }
}

public protocol IpTvProgrammesProvider {
    func load(_ completion: @escaping (Error?) -> Void)
    func list(for channel: Channel) -> ChannelProgramme?
}

public struct IpTvProgrammesProviders {
    public static func make(for provider: IpTvProviderKind) -> IpTvProgrammesProvider {
        switch provider {
        case .ottclub:
            return ProgrammesEgpFetcher(
                id: provider.name,
                url: URL(string: "http://myott.top/api/epg.xml.gz")! // https://vip-tv.org/articles/epg-iptv.html
            )
        case .plutoTv:
            return ProgrammesEgpFetcher(
                id: provider.name,
                url: URL(string: "https://raw.github.com/matthuisman/i.mjh.nz/master/PlutoTV/us.xml.gz")! // https://github.com/HelmerLuzo/PlutoTV_HL
            )
        case .dynamic:
            fatalError("Unsupported.")
        }
    }
}

internal class ProgrammesFetcherBase: IpTvProgrammesProvider {
    private var completion: ((Error?) -> Void)?
    private lazy var timer = Timer(timeInterval: 60 * 60 * 10, repeats: true) { [weak self] timer in
        if self == nil {
            timer.invalidate()
        } else {
            let _ = self?.completion.flatMap({ self?.load($0) })
        }
    }

    public final func load(_ completion: @escaping (Error?) -> Void) {
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

    final func list(for channel: Channel) -> ChannelProgramme? {
        return programmes[channel.id]
    }

    internal func fetch() {
        assertionFailure("Must implement in subclass.")
    }

    internal final func update(_ result: Swift.Result<[ChannelProgramme], Error>) {
        switch result {
        case .failure(let error):
            DispatchQueue.main.async {
                self.completion?(error)
            }
        case .success(let programmes):
            for p in programmes {
                self.programmes[p.channel.id] = p
            }
            DispatchQueue.main.async {
                self.completion?(nil)
            }
        }
    }

    private var programmes: [AnyHashable: ChannelProgramme] = [:]
}
