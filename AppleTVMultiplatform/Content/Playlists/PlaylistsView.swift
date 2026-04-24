
import SwiftUI
import NukeUI
import FactoryKit

struct PlaylistsView: View {

    @Binding var selectedPlaylist: PlaylistItem.Identity?
#if os(tvOS)
    @State private var showPlaylistSettings: PlaylistItem?
#endif
    @State private var viewModel = PlaylistsViewModel()
    @State private var showDeleteAlert = false
    @State private var deletePlaylist: PlaylistItem?
    @InjectedObservable(\.logger) var logger

    var body: some View {
        containerView()
            .task {
                viewModel.updatePlaylists()
            }
            .onChange(of: viewModel.selectedPlaylist) {
                selectedPlaylist = viewModel.onPlaylistSelection()
            }
            .onChange(of: selectedPlaylist) {
                viewModel.updateSelection(selectedPlaylist)
            }
        .alert("Delete", isPresented: $showDeleteAlert, actions: {
            Button("Delete", role: .destructive) {
                if let deletePlaylist {
                    viewModel.deletePlaylist(deletePlaylist)
                }
                deletePlaylist = nil
            }
            Button("Cancel", role: .cancel) {
                deletePlaylist = nil
            }
        })
#if os(tvOS)
            .sheet(item: $showPlaylistSettings) { playlist in
                PlaylistSettingsView(identity: playlist.identity!, onUpdate: .constant(.init()))
                    .padding(44)
            }
#endif
    }

    private func containerView() -> some View {
#if !os(tvOS)
        ContainerList(
            data: $viewModel.playlists,
            selection: $viewModel.selectedPlaylist,
            content: { playlist in
                contentView(playlist)
            },
            onDelete: { playlist in
                deletePlaylist = playlist
                showDeleteAlert = true
            }
        )
#else
        ContainerList(
            data: $viewModel.playlists,
            selection: $viewModel.selectedPlaylist,
            content: { playlist in
                contentView(playlist)
            },
            onDelete: { playlist in
                deletePlaylist = playlist
                showDeleteAlert = true
            },
            onSettings: { playlist in
                showPlaylistSettings = playlist
            }
        )
#endif
    }

    private func contentView(_ playlist: PlaylistItem) -> some View {
        HStack(spacing: 6) {
            if let icon = playlist.icon, let url = URL(string: icon) {
                LazyImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
#if os(tvOS)
                            .frame(height: 64)
#else
                            .frame(height: 44)
#endif
                    } else if let error = phase.error {
                        let _ = logger.error(error)
                        EmptyView()
                    } else {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
            }
            Text(playlist.name ?? "")
                .padding([.top, .bottom], 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ContainerList<Content: View>: View {
    
    @Binding var data: [PlaylistItem]
    @Binding var selection: PlaylistItem?
    let content: (PlaylistItem) -> Content
    let onDelete: (PlaylistItem) -> Void
#if os(tvOS)
    let onSettings: (PlaylistItem) -> Void
    @FocusState private var isRowFocused: PlaylistItem.Identity?
#endif

#if !os(tvOS)
    init(
        data: Binding<[PlaylistItem]>,
        selection: Binding<PlaylistItem?>,
        content: @escaping(PlaylistItem) -> Content,
        onDelete: @escaping(PlaylistItem) -> Void
    ) {
        self ._data = data
        self ._selection = selection
        self .content = content
        self .onDelete = onDelete
    }
#else
    init(
        data: Binding<[PlaylistItem]>,
        selection: Binding<PlaylistItem?>,
        content: @escaping(PlaylistItem) -> Content,
        onDelete: @escaping(PlaylistItem) -> Void,
        onSettings: @escaping(PlaylistItem) -> Void
    ) {
        self ._data = data
        self ._selection = selection
        self .content = content
        self .onDelete = onDelete
        self .onSettings = onSettings
    }
#endif

    var body: some View {
#if os(tvOS)
        List(data) { playlist in
            Button {
                selection = playlist
            } label: {
                content(playlist)
            }
            .modifier(ActionsViewModifier(
                onDelete: { onDelete(playlist) },
                onSettings: { onSettings(playlist) }
            ))
            .focused($isRowFocused, equals: playlist.identity)
            .onAppear {
                if data.first?.identity == playlist.identity {
                    isRowFocused = playlist.identity
                }
            }
        }
        .safeAreaPadding(.leading, 16)
        .safeAreaPadding(.trailing, 16)
#else
        List(data, selection: $selection) { playlist in
            content(playlist)
                .tag(playlist)
                .modifier(ActionsViewModifier(onDelete: { onDelete(playlist) }, share: playlist.transfer))
        }
#endif
    }
}

private struct ActionsViewModifier: ViewModifier {

    let onDelete: () -> Void
#if os(tvOS)
    let onSettings: () -> Void
#else
    let share: PlaylistItem.TransferIdentity?
    @State private var icon: Data?
#endif
    @InjectedObservable(\.logger) var logger

    func body(content: Content) -> some View {
        content
#if os(iOS)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                deleteButton()
                shareButton()
            }
#else
            .contextMenu {
                deleteButton()
    #if os(tvOS)
                settingsButton()
    #else
                shareButton()
    #endif
            }
#endif
#if !os(tvOS)
        .task {
            icon = await Task.detached {
                guard let share, let url = share.icon.flatMap({ URL.init(string: $0) }) else {
                    return Data()
                }
                let cacheURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(share.title)")
                    .appendingPathComponent("-\(share.identity.date.timeIntervalSince1970)-")
                    .appendingPathComponent(url.lastPathComponent)
                guard let cacheData = try? Data(contentsOf: cacheURL) else {
                    guard let data = try? Data(contentsOf: url) else {
                        return Data()
                    }
                    try? data.write(to: cacheURL)
                    return data
                }
                return cacheData
            }.value
        }
#endif
    }

    private func deleteButton() -> some View {
        DeleteButtonView {
            let _ = logger.info("Delete button event")
            onDelete()
        }
    }
#if os(tvOS)
    private func settingsButton() -> some View {
        SettingsButtonView {
            let _ = logger.info("Settings button event")
            onSettings()
        }
    }
#else
    @ViewBuilder
    private func shareButton() -> some View {
        if let share {
            if let icon, !icon.isEmpty {
                #if os(macOS)
                let image = NSImage(data: icon).map(SwiftUI.Image.init(nsImage:))
                #else
                let image = UIImage(data: icon).map(SwiftUI.Image.init(uiImage:))
                #endif
                if let image {
                    ShareLink(
                        item: share,
                        preview: SharePreview(Text(share.title), image: image)
                    )
                } else {
                    ShareLink(
                        item: share,
                        preview: SharePreview(Text(share.title))
                    )
                }
            } else {
                ShareLink(
                    item: share,
                    preview: SharePreview(Text(share.title))
                )
            }
        }
    }
#endif
}

#if DEBUG

import SwiftData

struct PlaylistsViewPreviews: PreviewProvider {
    
    static var previews: some View {
        Container.preview { container in
            container.databaseService.register {
                let database = DatabaseService(isStoredInMemoryOnly: true)
                let now = Date()
                let mainContext = database.mainContext
                mainContext.insert(
                    PlaylistItem(
                        name: "Netflix", date: now.addingTimeInterval(100),
                        icon: nil, url: nil, data: nil, salt: nil, encrypted: false
                    )
                )
                mainContext.insert(
                    PlaylistItem(
                        name: "America TV", date: now.addingTimeInterval(200),
                        icon: "https://raw.githubusercontent.com/mikehouse/Apple-TV-Player/refs/heads/master/logo.png",
                        url: nil, data: nil, salt: nil, encrypted: false
                    )
                )
                mainContext.insert(
                    PlaylistItem(
                        name: "Amazon", date: now.addingTimeInterval(300),
                        icon: nil, url: nil, data: nil, salt: nil, encrypted: false
                    )
                )
                mainContext.insert(
                    PlaylistItem(
                        name: "Hulu", date: now.addingTimeInterval(304),
                        icon: nil, url: nil, data: nil, salt: nil, encrypted: false
                    )
                )
                mainContext.insert(
                    PlaylistItem(
                        name: "HBO", date: now.addingTimeInterval(301),
                        icon: nil, url: nil, data: nil, salt: nil, encrypted: false
                    )
                )
                return database
            }
        }
        PreviewView()
    }
}

private struct PreviewView: View {
    
    @State var selectedPlaylist: PlaylistItem.Identity? = nil
    
    var body: some View {
        PlaylistsView(
            selectedPlaylist: $selectedPlaylist
        )
#if os(tvOS)
        .background(Color(uiColor: .darkGray))
#endif
#if os(macOS)
        .frame(width: 320)
#endif
    }
}

#endif
