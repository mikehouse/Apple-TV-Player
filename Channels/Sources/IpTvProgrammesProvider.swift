//
//  IpTvProgrammesProvider.swift
//  Channels
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import Foundation

public protocol IpTvProgrammesProvider {
    func load(_ completion: @escaping (Error?) -> Void)
    func list(for channel: Channel) -> [String]
}

public struct IpTvProgrammesProviders {
    public static func make(for provider: IpTvProviderKind) -> IpTvProgrammesProvider {
        switch provider {
        case .ru2090000:
            return ProgrammesFetcher2090000()
        case .dynamic:
            fatalError("Unsupported.")
        }
    }
}
