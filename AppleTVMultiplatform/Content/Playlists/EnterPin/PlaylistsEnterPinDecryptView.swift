
import SwiftUI

struct PlaylistsEnterPinDecryptView: View {

    @Binding var selectedPlaylistContent: PlaylistItem.Content?
    @State private var viewModel: PlaylistsEnterPinDecryptViewModel
    @Environment(\.dismiss) var dismiss

    init(
        identity: PlaylistItem.Identity,
        selectedPlaylistContent: Binding<PlaylistItem.Content?>
    ) {
        self._selectedPlaylistContent = selectedPlaylistContent
        self._viewModel = State(initialValue: PlaylistsEnterPinDecryptViewModel(identity: identity))
    }

    var body: some View {
        EnterPinView(pin: $viewModel.pin) {
            Task {
                if let value = await viewModel.onPinInput() {
                    selectedPlaylistContent = value
                    dismiss()
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
                .accessibilityIdentifier("ok")
        } message: {
            Text(viewModel.message)
        }
    }
}

#if DEBUG

struct PlaylistsEnterPinDecryptViewPreviews: PreviewProvider {
    
    static var previews: some View {
#if os(macOS)
    PlaylistsEnterPinDecryptView(
        identity: .init(name: "Abc", date: Date()),
        selectedPlaylistContent: .constant(nil)
    )
    .frame(width: 300)
#else
    Text("")
        .sheet(isPresented: .constant(true)) {
    #if os(iOS)
            NavigationStack {
                PlaylistsEnterPinDecryptView(
                    identity: .init(name: "Abc", date: Date()),
                    selectedPlaylistContent: .constant(nil)
                )
                .presentationDetents([.height(260)])
            }
    #else
            PlaylistsEnterPinDecryptView(
                identity: .init(name: "Abc", date: Date()),
                selectedPlaylistContent: .constant(nil)
            )
            .background()
    #endif
        }
#endif
    }
}

#endif
