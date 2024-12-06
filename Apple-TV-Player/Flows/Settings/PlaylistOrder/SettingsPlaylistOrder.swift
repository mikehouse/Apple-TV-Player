//
//  SettingsPlaylistOrder.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 24.11.2024.
//

import SwiftUI

struct SettingsPlaylistOrder: View {

    private let storage: LocalStorage

    @State private var playlistOrder: LocalStorage.PlaylistOrder {
        didSet {
            storage.playlistOrder = playlistOrder
        }
    }

    init(storage: LocalStorage) {
        self.storage = storage
        _playlistOrder = State(initialValue: storage.playlistOrder ?? .default)
    }

    var body: some View {
        List {
            ForEach(LocalStorage.PlaylistOrder.allCases) { item in
                Button {
                    guard self.playlistOrder != item else {
                        return
                    }
                    self.playlistOrder = item
                } label: {
                    HStack {
                        Text(item.description)
                        Spacer()
                        if playlistOrder == item {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}

struct SettingsChannelsSortingMode_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPlaylistOrder(storage: LocalStorage(storage: .init()))
    }
}
