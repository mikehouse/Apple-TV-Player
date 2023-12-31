//
//  SettingsPlayersView.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 28.12.2023.
//

import SwiftUI

struct SettingsPlayersView: View {

    private let storage: LocalStorage
    
    @State private var player: LocalStorage.Player

    init(storage: LocalStorage) {
        self.storage = storage
        _player = State(initialValue: storage.getPlayer() ?? .default)
    }

    var body: some View {
        List {
            ForEach(LocalStorage.Player.allCases) { item in
                Button {
                    guard self.player != item else {
                        return
                    }
                    self.storage.set(player: item)
                    self.player = item
                } label: {
                    HStack {
                        Text(item.title)
                        Spacer()
                        if self.player == item {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}

struct SettingsPlayersView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPlayersView(storage: LocalStorage(storage: .init()))
    }
}
