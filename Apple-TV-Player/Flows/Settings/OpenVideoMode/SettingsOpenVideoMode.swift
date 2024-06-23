//
//  SettingsOpenVideoMode.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 22.06.2024.
//

import SwiftUI

struct SettingsOpenVideoMode: View {

    private let storage: LocalStorage

    @State private var openVideoMode: LocalStorage.OpenVideoMode {
        didSet {
            storage.openVideoMode = openVideoMode
        }
    }

    init(storage: LocalStorage) {
        self.storage = storage
        _openVideoMode = State(initialValue: storage.openVideoMode ?? .fullScreen)
    }

    var body: some View {
        List {
            ForEach(LocalStorage.OpenVideoMode.allCases) { item in
                Button {
                    guard self.openVideoMode != item else {
                        return
                    }
                    self.openVideoMode = item
                } label: {
                    HStack {
                        Text(item.title)
                        Spacer()
                        if openVideoMode == item {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
    }
}

struct SettingsOpenVideoMode_Previews: PreviewProvider {
    static var previews: some View {
        SettingsOpenVideoMode(storage: LocalStorage(storage: .init()))
    }
}
