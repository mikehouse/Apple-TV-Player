//
//  SettingsDebugView.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 31.12.2023.
//

import SwiftUI

struct SettingsDebugView: View {
    
    private let storage: LocalStorage
    @State private var selected: Bool
    
    init(storage: LocalStorage) {
        self.storage = storage
        self._selected = State(initialValue: storage.getBool(.debugMenu, domain: .common))
    }
    
    var body: some View {
        VStack {
            Button {
                selected = !selected
                storage.add(value: selected, for: .debugMenu, domain: .common)
            } label: {
                HStack {
                    Text(NSLocalizedString("Debug menu", comment: ""))
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                    }
                }
            }
            Spacer()
        }
    }
}

struct SettingsDebugView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsDebugView(storage: .init(storage: .init()))
    }
}
