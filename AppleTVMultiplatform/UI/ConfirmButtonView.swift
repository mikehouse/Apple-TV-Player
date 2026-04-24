
import SwiftUI

struct ConfirmButtonView: View {

    let action: @MainActor () -> Void

    var body: some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            Button("Done", systemImage: "checkmark", role: nil, action: action)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("confirm")
        } else {
            Button("Done", action: action)
                .accessibilityIdentifier("confirm")
        }
        #else
        Button("Done", action: action)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("confirm")
        #endif
    }
}
