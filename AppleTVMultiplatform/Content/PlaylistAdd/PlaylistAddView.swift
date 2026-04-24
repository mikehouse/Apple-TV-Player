import FactoryKit
import SwiftUI

struct PlaylistAddView: View {

    @InjectedObservable(\.logger) var logger
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PlaylistAddViewModel()
    @State private var task: Task<Void, Error>?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack {
            List {
                Section("Playlist") {
                    HStack {
                        Text("Name")
                        textField("Optional", text: $viewModel.name)
                            .focused($isTextFieldFocused)
                            .onAppear {
                                if ProcessInfo.processInfo.isPreview || ProcessInfo.processInfo.isRunningUITests {
                                    return
                                }
                                isTextFieldFocused = true
                            }
                            .accessibilityIdentifier("name")
                    }
                    HStack {
                        Text(verbatim: "URL")
                        textField("Required", text: $viewModel.urlString)
                            .modifier(KeyboardURLTypeModifier())
                            .accessibilityIdentifier("url")
                    }
                    HStack {
                        Text("Passcode")
                        textField("Optional", text: $viewModel.pin)
                            .accessibilityIdentifier("passcode")
                    }
                }

                Section("Tags") {
                    HStack {
                        Text(verbatim: "tvg-logo")
                        textField("Optional", text: $viewModel.tvgLogo)
                            .modifier(KeyboardURLTypeModifier())
                            .accessibilityIdentifier("tvg-logo")
                    }
                    HStack {
                        Text(verbatim: "url-tvg")
                        textField("Optional", text: $viewModel.urlTvg)
                            .modifier(KeyboardURLTypeModifier())
                            .accessibilityIdentifier("url-tvg")
                    }
                    HStack {
                        Text(verbatim: "url-img")
                        textField("Optional", text: $viewModel.urlImg)
                            .modifier(KeyboardURLTypeModifier())
                            .accessibilityIdentifier("url-img")
                    }
                }
            }
#if os(macOS)
            .cornerRadius(24)
#endif
#if !os(iOS)
            Spacer()
            HStack {
                cancelButtonView()
                Spacer()
                addButtonView()
            }
#endif
        }
        .disabled(viewModel.isLoading)
#if os(iOS)
        .navigationBarTitle(String(localized: "Add Playlist"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                addButtonView()
            }
            ToolbarItem(placement: .cancellationAction) {
                cancelButtonView()
            }
        }
#endif
        .overlay {
            if viewModel.isLoading {
                BlurProgressView(viewModel.progress)
            }
        }
        .alert("Unable to Add Playlist", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }

#if os(tvOS)
        .padding(44)
        .frame(minHeight: UIScreen.main.bounds.height * 0.85)
        .frame(minWidth: UIScreen.main.bounds.width / 2.5)
#elseif os(macOS)
        .padding()
        .frame(minHeight: 344)
        .listStyle(.sidebar)
#endif
        .onDisappear {
            task?.cancel()
        }
    }
    
    private func cancelButtonView() -> some View {
        CancelButtonView {
            logger.info("Cancel button event")
            dismiss()
        }
    }

    @ViewBuilder
    private func addButtonView() -> some View {
#if os(tvOS)
        let view = AddButtonView(isToolbar: false) {
            logger.info("Add playlist button event")
            addPlaylist()
        }
#elseif os(iOS)
        let view = ConfirmButtonView {
            logger.info("Add playlist button event")
            addPlaylist()
        }
#else
        let view = AddButtonView {
            logger.info("Add playlist button event")
            addPlaylist()
        }
#endif
        view
            .disabled(!viewModel.canAdd)
    }

    func textField(_ titleKey: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(titleKey, text: text)
            .autocorrectionDisabled()
#if os(iOS)
            .textFieldStyle(.plain)
#elseif os(macOS)
            .textFieldStyle(.roundedBorder)
#endif
    }

    private func addPlaylist() {
        task = Task { @MainActor in
            if await viewModel.addPlaylist() {
                dismiss()
            }
        }
    }
}

private struct KeyboardURLTypeModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
#if os(iOS)
            .keyboardType(.URL)
#endif
    }
}

#if DEBUG

struct PlaylistAddViewPreviews: PreviewProvider {
    
    static var previews: some View {
        Container.preview { container in
            container.playlistAddService.register {
                PlaylistAddErrorServicePreviewMock()
            }
            container.databaseService.register {
                DatabaseService(isStoredInMemoryOnly: true)
            }
        }
#if os(macOS)
        PlaylistAddView()
            .frame(width: 360)
#else
        Text("")
            .sheet(isPresented: .constant(true)) {
    #if os(iOS)
                NavigationStack {
                    PlaylistAddView()
                }
    #else
                PlaylistAddView()
                    .background()
    #endif
            }
#endif
    }
    
}


private final class PlaylistAddErrorServicePreviewMock: PlaylistAddServiceInterface {
    func preparePlaylist(
        name: String?,
        urlString: String,
        pin: String?,
        urlTvg: String?,
        urlImg: String?,
        tvgLogo: String?,
        progress: ProgressHandler
    ) async throws -> PreparedPlaylist {
        throw NSError(domain: "error.domain.preview", code: 11)
    }

    func restorePlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String?) async throws -> RestoredPlaylist {
        throw NSError(domain: "error.domain.preview", code: 12)
    }
    func encryptPlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String) async throws -> PreparedPlaylist {
        .init(name: "", date: .init(), icon: nil, url: .init(), data: .init(), salt: nil, encrypted: false)
    }
}

#endif
