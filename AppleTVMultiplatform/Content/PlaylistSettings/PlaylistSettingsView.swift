
import FactoryKit
import SwiftUI

struct PlaylistSettingsView: View {

    @Binding var onUpdate: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlaylistSettingsViewModel
    @InjectedObservable(\.logger) var logger

    init(identity: PlaylistItem.Identity, onUpdate: Binding<UUID>) {
        _viewModel = State(initialValue: PlaylistSettingsViewModel(identity: identity))
        _onUpdate = onUpdate
    }

    var body: some View {
        contentView()
            .onChange(of: viewModel.order) { _, _ in
                if viewModel.onOrderChange() {
                    onUpdate = .init()
                }
            }
            .onChange(of: viewModel.pinEnabled) { _, _ in
                viewModel.onPinChange()
            }
            .disabled(viewModel.progress)
            .overlay {
                if let progressText = viewModel.progressText {
                    BlurProgressView(progressText.string)
                }
            }
            .sheet(isPresented: $viewModel.showPinCodeDecryptView, onDismiss: {
                Task {
                    _ = await viewModel.onDecrypt()
                }
            }) {
                sheetView {
                    pinCodeDecryptSheet(viewModel.identity)
                }
            }
            .sheet(isPresented: $viewModel.showPinCodeEncryptView, onDismiss: {
                Task {
                    _ = await viewModel.onEncrypt()
                }
            }) {
                sheetView {
                    pinCodeEncryptSheet()
                }
            }
            .sheet(isPresented: $viewModel.showPinCodeDecryptProgramGuideView, onDismiss: {
                Task {
                    if await viewModel.updateProgramGuideDecrypted() {
                        onUpdate = .init()
                    }
                }
            }) {
                sheetView {
                    pinCodeDecryptSheet(viewModel.identity)
                }
            }
            .sheet(isPresented: $viewModel.showPinCodeDecryptPlaylistView, onDismiss: {
                Task {
                    if await viewModel.updatePlaylistDecrypted() {
                        onUpdate = .init()
                    }
                }
            }) {
                sheetView {
                    pinCodeDecryptSheet(viewModel.identity)
                }
            }
            .alert(isPresented: .constant(false), error: viewModel.error, actions: {
                Button("OK") {
                }
            })
    }

    private func pinCodeDecryptSheet(_ identity: PlaylistItem.Identity) -> some View {
        PlaylistsEnterPinDecryptView(
            identity: identity,
            selectedPlaylistContent: $viewModel.playlistDecryptedContent
        )
    }

    private func pinCodeEncryptSheet() -> some View {
        EnterPinView(pin: $viewModel.pin) {
            viewModel.showPinCodeEncryptView = false
        }
    }

    private func sheetView<Content: View>(_ content: () -> Content) -> some View {
#if os(iOS)
        NavigationStack {
            content()
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(true)
#else
        content()
            .interactiveDismissDisabled(true)
#endif
    }

    @ViewBuilder
    private func contentView() -> some View {
        VStack {
            List {
#if os(iOS)
                let title = ""
#else
                let title = String(localized: "Settings")
#endif
                Section(title) {
                    sortOptions()
                    pinOptions()
                    updateProgramGuideOptions()
                    updatePlaylistOptions()
                }
            }
#if os(macOS)
            .cornerRadius(24)
            .listStyle(.inset)
#endif
            Spacer()
#if !os(iOS)
            HStack {
                cancelButtonView()
                Spacer()
                confirmButtonView()
            }
#endif
        }
#if os(iOS)
        .ignoresSafeArea(.container, edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                confirmButtonView()
            }
            ToolbarItem(placement: .cancellationAction) {
                cancelButtonView()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
#elseif os(tvOS)
        .padding(44)
        .frame(minHeight: UIScreen.main.bounds.height * 0.6)
        .frame(minWidth: UIScreen.main.bounds.width / 1.6)
#elseif os(macOS)
        .padding()
        .frame(minHeight: 240)
#endif
    }

    private func cancelButtonView() -> some View {
        CancelButtonView {
            let _ = logger.info("Cancel button event")
            dismiss()
        }
        .disabled(viewModel.dataChanged)
    }

    private func confirmButtonView() -> some View {
        ConfirmButtonView {
            let _ = logger.info("Confirm button event")
            dismiss()
        }
        .disabled(!viewModel.dataChanged)
    }
    
    private func sortOptions() -> some View {
        HStack {
            Image(systemName: "list.number")
            Text("Sort by")
            Spacer()

            let picker = Picker("", selection: $viewModel.order) {
                ForEach(PlaylistSettingsItem.StreamListOrder.allCases, id: \.self) { option in
                    Text(option.title)
                        .tag(option)
                        .accessibilityIdentifier(option.title)

                }
            }
            .accessibilityIdentifier("sort-by-picker")
#if os(tvOS)
            Menu {
                picker
            } label: {
                HStack(spacing: 8) {
                    Text(viewModel.order.title)
                        .fixedSize()
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
#else
            picker
#endif
        }
    }
    
    private func pinOptions() -> some View {
        HStack {
            Image(systemName: "lock.square.stack")
            Text("Passcode")
            Spacer()
            let picker = Picker("", selection: $viewModel.pinEnabled) {
                ForEach([true, false], id: \.self) { option in
                    Text(option ? String(localized: "Enabled") : String(localized: "Disabled"))
                        .tag(option)
                        .accessibilityIdentifier(option ? "passcode-enable" : "passcode-disable")
                }
            }
            .accessibilityIdentifier("passcode-picker")
#if os(tvOS)
            Menu {
                picker
            } label: {
                HStack(spacing: 8) {
                    Text(viewModel.pinEnabled ? String(localized: "Enabled") : String(localized: "Disabled"))
                        .fixedSize()
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
#else
            picker
#endif
        }
    }

    private func updateProgramGuideOptions() -> some View {
        HStack {
            Image(systemName: "arrow.counterclockwise")
            Text("Update Program Guide")
            Spacer()
            Button {
                Task {
                    if await viewModel.updateProgramGuide() {
                        onUpdate = .init()
                    }
                }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
        }
    }

    private func updatePlaylistOptions() -> some View {
        HStack {
            Image(systemName: "arrow.counterclockwise")
            Text("Update Playlist")
            Spacer()
            Button {
                Task {
                    if await viewModel.updatePlaylist() {
                        onUpdate = .init()
                    }
                }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.bordered)
        }
    }
}

#if DEBUG

struct PlaylistSettingsViewPreviews: PreviewProvider {
    
    static var previews: some View {
        let view: () -> some View = {
            PlaylistSettingsView(
                identity: .init(name: "1", date: Date()),
                onUpdate: .constant(.init())
            )
        }
#if !os(macOS)
        Text("")
            .sheet(isPresented: .constant(true)) {
                #if os(tvOS)
                view()
                    .background()
                #else
                NavigationStack {
                    view()
                }
                .presentationDetents([.medium, .large])
                #endif
            }
#else
        view()
            .frame(width: 400, height: 300)
#endif
    }
}

#endif
