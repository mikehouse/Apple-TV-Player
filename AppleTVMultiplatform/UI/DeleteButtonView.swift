
import SwiftUI

struct DeleteButtonView: View {

    let action: @MainActor () -> Void

    var body: some View {
#if os(tvOS)
        Button("Delete", systemImage: "trash", role: .destructive, action: action)
#else
        Button("Delete", systemImage: "trash", role: .destructive, action: action)
#endif
    }
}
