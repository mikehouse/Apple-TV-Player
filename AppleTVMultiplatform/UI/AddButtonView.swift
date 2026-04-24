
import SwiftUI

struct AddButtonView: View {

#if os(tvOS)
    let isToolbar: Bool
#endif

    let action: @MainActor () -> Void

    var body: some View {
#if !os(tvOS)
        Button("Add", systemImage: "plus", role: .none, action: action)
            .accessibilityIdentifier("add")
    #if os(iOS)
            .tint(.primary)
    #endif
    #if os(macOS)
            .buttonStyle(.borderedProminent)
    #endif
#else
        Button(isToolbar ? "" : String(localized: "Add"), systemImage: "plus", role: .none, action: action)
            .accessibilityIdentifier("add")
#endif
    }
}
