
import SwiftUI

struct SettingsButtonView: View {

    let action: @MainActor () -> Void

    var body: some View {
        Button("Settings", systemImage: "gearshape", role: nil, action: action)
            .accessibilityIdentifier("settings")
            #if os(iOS)
            .tint(.primary)
            #endif
    }
}
