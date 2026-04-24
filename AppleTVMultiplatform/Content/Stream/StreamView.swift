import AVKit
import FactoryKit
import SwiftUI
import Combine

// Some members of my family used to old layout on Apple TV.
private let homeTvOSStreamLayout = false

struct StreamView: View {

    @InjectedObservable(\.logger) var logger
    @State private var viewModel: StreamViewModel
    @Binding private var reloadCurrentProgram: UUID
#if os(tvOS)
    @FocusState private var isButtonFocused: Bool
    @State private var showFullScreen = false
    @State private var tvOSPlayer: TvOSPlayer
    @State private var reloadProgramGuide = UUID()
    @Binding private var reselectStream: Bool
    @Binding var focusedStream: PlaylistParser.Stream?

    init(
        content: PlaylistItem.Content,
        stream: PlaylistParser.Stream,
        reselectStream: Binding<Bool>,
        focusedStream: Binding<PlaylistParser.Stream?>,
        reloadCurrentProgram: Binding<UUID>
    ) {
        _viewModel = State(wrappedValue: StreamViewModel(content: content, stream: stream))
        _tvOSPlayer = State(wrappedValue: TvOSPlayer(urlString: stream.url))
        _reselectStream = reselectStream
        _focusedStream = focusedStream
        _reloadCurrentProgram = reloadCurrentProgram
    }
#else
    init(
        content: PlaylistItem.Content,
        stream: PlaylistParser.Stream,
        reloadCurrentProgram: Binding<UUID>
    ) {
        _viewModel = State(wrappedValue: StreamViewModel(content: content, stream: stream))
        _reloadCurrentProgram = reloadCurrentProgram
    }
#endif

    var body: some View {
        ZStack {
            TimelineView(.periodic(from: Date(), by: 60)) { context in
#if os(tvOS)
                let _ = viewModel.displayedPrograms(at: context.date, stream: focusedStream ?? viewModel.stream)
#else
                let _ = viewModel.displayedPrograms(at: context.date, stream: viewModel.stream)
#endif

                VStack(alignment: .leading, spacing: 16) {
#if os(tvOS)
                    if !homeTvOSStreamLayout {
                        headerView(now: context.date)
                            .padding(.trailing, 22)
                        videoPlayer()
                        programList()
                            .id(reloadProgramGuide)
                    } else {
                        ZStack {
                            VStack {
                                headerView(now: context.date)
                                    .padding(.trailing, 22)
                                programList()
                                    .id(reloadProgramGuide)
                                    .padding(.bottom, 24)
                            }
                            VStack {
                                Spacer()
                                HStack {
                                    videoPlayer()
                                    Spacer()
                                }
                            }
                        }
                    }
#else
                    videoPlayer()
                    programList()
#endif
                }
                .padding([.leading, .trailing, .bottom])
            }
        }
#if os(iOS)
        .navigationBarTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task(id: reloadCurrentProgram) {
            await viewModel.loadPrograms()
        }
#if os(tvOS)
        .fullScreenCover(isPresented: $showFullScreen, onDismiss: {
            reloadCurrentProgram = .init()
        }) {
            let _ = logger.info("Presenting full screen from floating player", private: viewModel.stream.title)
            tvOSPlayer.fullScreenView()
        }
        .fullScreenCover(isPresented: $reselectStream, onDismiss: {
            reloadCurrentProgram = .init()
        }) {
            let _ = logger.info("Presenting full screen from double select", private: viewModel.stream.title)
            tvOSPlayer.fullScreenView()
        }
        .onChange(of: focusedStream) {
            if let focusedStream {
                Task {
                    if await viewModel.loadPrograms(focusedStream) {
                        reloadProgramGuide = UUID()
                    }
                }
            }
        }
#endif
    }
#if os(tvOS)
    private func headerView(now: Date) -> some View {
        HStack {
            if !homeTvOSStreamLayout,
               focusedStream != viewModel.stream,
               let currentProgram = viewModel.originStreamCurrentProgram {
                Text(currentProgram.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            } else {
                Spacer()
            }

            HStack(spacing: 10) {
                Text(viewModel.title)
                Text(viewModel.currentTimeText(at: now))
            }
            .font(.headline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
#endif
    private func videoPlayer() -> some View {
#if os(macOS)
        MacOsPlayerView(urlString: viewModel.stream.url) {
            reloadCurrentProgram = .init()
        }
#elseif os(tvOS)
        HStack(spacing: 0) {
            Button {
                showFullScreen = true
            } label: {
                tvOSPlayer.compactView()
            }
            .buttonStyle(.borderless)
            .cornerRadius(homeTvOSStreamLayout ? 0 : 24)
            .shadow(color: (isButtonFocused ? Color.white : Color.black).opacity(0.4), radius: 12, x: 0, y: 0)
            .focused($isButtonFocused)
        }
        .ignoresSafeArea()
#else
        iOSPlayerView(urlString: viewModel.stream.url)
#endif
    }

    private func programList() -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.displayProgram) { displayedProgram in
#if os(tvOS)
                    Button {
                    } label: {
                        program(displayedProgram)
                    }
                    .buttonStyle(.borderless)
#else
                    program(displayedProgram)
#endif
                }
            }
        }
        .accessibilityIdentifier("program-list")
    }

    private func program(_ displayedProgram: StreamViewModel.DisplayProgram) -> some View {
        Text(displayedProgram.text)
            .foregroundStyle(color(for: displayedProgram.state))
#if os(tvOS)
            .font(.system(size: 31, weight: .regular))
#endif
    }

    private func color(for state: StreamViewModel.ProgramState) -> Color {
        switch state {
        case .past:
            .secondary
        case .now:
            .green
        case .future:
            .primary
        }
    }
}

#if os(macOS)
private struct MacOsPlayerView: NSViewRepresentable {

    let urlString: String
    let onExitFullScreen: () -> Void

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = URL(string: urlString).map { AVPlayer(url: $0) }
        view.showsFullScreenToggleButton = true
        view.controlsStyle = .inline
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player?.play()
    }

    func makeCoordinator() -> PlayerDelegate {
        return PlayerDelegate(onExitFullScreen: onExitFullScreen)
    }

    static func dismantleNSView(_ nsView: Self.NSViewType, coordinator: Self.Coordinator) {
        nsView.player?.pause()
        nsView.player = nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Self.NSViewType, context: Self.Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return .init(width: width, height: width * (9.0 / 16.0))
    }

    class PlayerDelegate: NSObject, AVPlayerViewDelegate {

        let onExitFullScreen: () -> Void

        init(onExitFullScreen: @escaping () -> Void) {
            self.onExitFullScreen = onExitFullScreen
            super.init()
        }

        func playerViewWillExitFullScreen(_ playerView: AVPlayerView) {
            onExitFullScreen()
        }
    }
}
#elseif os(tvOS)
private struct TvOSPlayerView: UIViewControllerRepresentable {

    let player: AVPlayer
    let compact: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player?.play()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Self.UIViewControllerType, context: Self.Context) -> CGSize? {
        let multiplier: CGFloat = homeTvOSStreamLayout ? 1 : 2.8 / 3.0
        guard compact, let width = proposal.width.map({ $0 * multiplier }) else { return nil }
        return .init(width: width, height: width * (9.0 / 16.0))
    }
}

private final class TvOSPlayer {

    let player: AVPlayer

    init(urlString: String) {
        player = AVPlayer(url: URL(string: urlString)!)
    }

    func compactView() -> some View {
        TvOSPlayerView(player: player, compact: true)
    }

    func fullScreenView() -> some View {
        TvOSPlayerView(player: player, compact: false)
            .ignoresSafeArea()
    }

    deinit {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }
}
#else
private struct iOSPlayerView: UIViewControllerRepresentable {

    let urlString: String

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetoothHFP, .allowBluetoothA2DP])
            try session.setActive(true)
        } catch {
            Container.shared.logger().error(error)
        }
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: URL(string: urlString)!)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player?.play()
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Self.Coordinator) {
        uiViewController.player?.pause()
        uiViewController.player = nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Self.UIViewControllerType, context: Self.Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return .init(width: width, height: width * (9.0 / 16.0))
    }
}
#endif

#if DEBUG

struct StreamViewPreviews: PreviewProvider {
    
    static var previews: some View {
        Container.preview { container in
            container.playlistService.register {
                ProgramGuidePlaylistServicePreviewMock()
            }
        }
        let content = PlaylistItem.Content(
           identity: .init(
               name: "Preview",
               date: Date(timeIntervalSince1970: 100)
           ),
           url: Data("https://example.com/playlist.m3u".utf8),
           data: Data("#EXTM3U".utf8),
           isStoredInMemoryOnly: true
       )
        let stream = PlaylistParser.Stream(
           title: "Channel",
           url: "https://example.com/master.m3u8",
           tvgLogo: nil,
           tvgID: nil,
           tvgName: "Channel HD",
           groupTitle: nil
       )

#if os(iOS)
        NavigationStack {
            StreamView(
                content: content, stream: stream,
                reloadCurrentProgram: .constant(.init())
            )
        }
#elseif os(macOS)
        StreamView(
            content: content, stream: stream,
            reloadCurrentProgram: .constant(.init())
        )
        .frame(width: 600, height: 460)
#else
        HStack {
            Rectangle()
                .fill(.clear)
                .frame(width: UIScreen.main.bounds.width / 4)
                
            StreamView(
                content: content,
                stream: stream,
                reselectStream: .constant(false),
                focusedStream: .constant(nil),
                reloadCurrentProgram: .constant(.init())
            )
            .background(Color(uiColor: .darkGray))
        }
#endif
    }
}

private final class ProgramGuidePlaylistServicePreviewMock: PlaylistServiceInterface {

    func playlists(
        for content: PlaylistItem.Content,
        reloadProgramGuide: Bool,
        progress: @escaping ProgressHandler
    ) async throws -> [PlaylistParser.Playlist] {
        []
    }

    func playlists(
        for content: PlaylistItem.Content,
        reloadPlaylist: Bool,
        progress: @escaping ProgressHandler
    ) async throws -> [PlaylistParser.Playlist] {
        []
    }

    func programGuide(
        for content: PlaylistItem.Content,
        stream: PlaylistParser.Stream
    ) async -> ProgramGuide? {
        let now = Date()

        return ProgramGuide(
            channel: .init(
                id: "preview",
                displayName: "Preview Channel HD",
                iconURL: nil
            ),
            programs: [
                .init(
                    title: "Pre-Late Show",
                    start: now.addingTimeInterval(-6000),
                    stop: now.addingTimeInterval(-3600)
                ),
                .init(
                    title: "Late Show",
                    start: now.addingTimeInterval(-3600),
                    stop: now.addingTimeInterval(-1800)
                ),
                .init(
                    title: "News",
                    start: now.addingTimeInterval(-1800),
                    stop: now.addingTimeInterval(1800)
                ),
                .init(
                    title: "Movie",
                    start: now.addingTimeInterval(1800),
                    stop: now.addingTimeInterval(5400)
                ),
                .init(
                    title: "Night Show",
                    start: now.addingTimeInterval(5400),
                    stop: now.addingTimeInterval(8400)
                )
            ]
        )
    }

    func clearCache(for content: PlaylistItem.Content) async {
    }

    func programGuides(for content: PlaylistItem.Content, since: Date) async -> [ProgramGuide] {
        []
    }
}

#endif
