//
//  ProgrammesFetcher2090000.swift
//  Channels
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import Foundation

internal final class ProgrammesFetcher2090000: ProgrammesFetcherBase {

    override func fetch() {
        // TODO: Reimplement for new format.
        // https://2090000.ru/programma-peredach/
        update(.success([]))
    }
}
