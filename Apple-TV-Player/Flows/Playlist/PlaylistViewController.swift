//
//  PlaylistViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 14.11.2020.
//

import UIKit
import Reusable
import Channels
import CryptoKit

final class PlaylistViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var programmesStackView: UIStackView!
    @IBOutlet private var timeLabel: UILabel!
    @IBOutlet private var channelNameLabel: UILabel!
    @IBOutlet private var debugView: UIStackView!
    @IBOutlet private var debugViewTopConstraint: NSLayoutConstraint!
    @IBOutlet private var programmesLoadingLabel: UILabel!
    @IBOutlet private var programmesLoadingIndicator: UIActivityIndicatorView!

    private var debugViewEnabled = false
    private lazy var memStatsDebugView: UILabel = {
        let view = UILabel()
        view.textColor = .tertiaryLabel
        view.font = .preferredFont(forTextStyle: .footnote)
        view.textAlignment = .right
        view.numberOfLines = 0
        return view
    }()

    var playlist: Playlist?
    var pinData: Data?
    private var orderedChannels: [Channel]?
    var programmes: IpTvProgrammesProvider?
    
    private var currentFocusPath: IndexPath?
    private var currentPlayingPath: IndexPath?
    private var timeUpdateTimer: Timer?
    private weak var overlayPlayer: ChannelPlayerViewController?
    private var logosCache: [IndexPath:UIImage] = [:]
    private var currentProgrammeNameCache: [IndexPath:String] = [:]
    private var debugMenuDataProvider: DebugMenuDataProvider?
    private var reloadAfterDelayedFetch = false
    private var tableViewHeight: CGFloat = 72
    private var hdFixCache: [AnyHashable: Channel] = [:]
    private var startFullScreenTime = CFAbsoluteTimeGetCurrent()
    private var isFullScreen = false
    private let shadowPreviewView = ShadowView()
    private lazy var storage: LocalStorage = .init(storage: .app)
    private lazy var fsManager = FileSystemManager()

    private lazy var channelICO: ChannelICOProvider = {
        ChannelICO(locale: playlist?.name == "Pluto TV" ? "us" : "ru")
    }()
    private lazy var dataSource = DataSource(tableView: self.tableView) { [weak self] tableView, indexPath, row in
        guard let self else {
            return UITableViewCell()
        }
        let cell: PlaylistChannelViewCell = tableView.dequeueReusableCell(
            for: indexPath, cellType: PlaylistChannelViewCell.self)
        cell.textLabel?.text = row.channel.name
        cell.detailTextLabel?.text = self.currentProgrammeNameCache[indexPath]
        if let image = self.logosCache[indexPath] {
            cell.imageView?.image = image
        } else {
            cell.imageView?.image = nil
            self.channelICO.icoFetch(for: row.channel) { [name=row.channel.name, weak self] (_, image) in
                guard cell.textLabel?.text == name else {
                    return
                }
                guard let image else {
                    cell.imageView?.image = nil
                    return
                }
                let uiImage = UIImage(cgImage: image)

                cell.imageView?.image = uiImage
                self?.logosCache[indexPath] = uiImage
            }
        }
        return cell
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        additionalSafeAreaInsets = .init(top: -32, left: -32, bottom: -32, right: -46)

        debugViewEnabled = storage.getBool(.debugMenu, domain: .common)
    
        configureTableView()
        configureTimeLabel()
        loadPlaylist()
        programmes?.load { [weak self] error in
            self?.programmesLoadingIndicator(hidden: true)
            if let error = error {
                logger.error("\(error)")
            } else {
                self?.updateProgrammesVisibleCells()
            }
        }

        if programmes != nil {
            programmesLoadingIndicator(hidden: false)
            tableViewHeight = 86
        } else {
            programmesLoadingIndicator(hidden: true)
        }
        
        for view in debugView.arrangedSubviews {
            debugView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        shadowPreviewView.backgroundColor = .white
        
        guard debugViewEnabled else {
            debugViewTopConstraint.constant = 0
            return
        }

        debugView.addArrangedSubview(memStatsDebugView)

        debugMenuDataProvider = .init { [weak self] data in
            guard self?.isFullScreen ?? true == false else {
                self?.overlayPlayer?.debugView.text = data
                self?.memStatsDebugView.text = nil
                return
            }
            self?.overlayPlayer?.debugView.text = nil
            self?.memStatsDebugView.text = data
        }
    }
    
    deinit {
        logger.info("deinit \(self)")
    }
}

private extension PlaylistViewController {
    enum Section: Hashable {
        case main
    }
    struct Row: Hashable {
        let channel: Channel
        var id: AnyHashable { channel.id }
    
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    
        static func ==(lhs: Row, rhs: Row) -> Bool {
            return lhs.id == rhs.id
        }
    }
}

private extension PlaylistViewController {
    final class DataSource: UITableViewDiffableDataSource<Section, Row> {
    }
}

private extension PlaylistViewController {
    func configureTableView() {
        tableView.register(cellType: PlaylistChannelViewCell.self)
        tableView.delegate = self
        tableView.prefetchDataSource = self
        tableView.dataSource = dataSource
    }
    
    func configureTimeLabel() {
        channelNameLabel.text = nil
        timeLabel.text = nil
    
        timeLabel.text = Self.dateFormatter.string(from: .init())
        timeUpdateTimer = .scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.timeLabel.text = Self.dateFormatter.string(from: .init())
        }
    }
    
    func loadPlaylist() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard var playlist = self.playlist?.channels, !playlist.isEmpty, let name = self.playlist?.name else {
                DispatchQueue.main.async {
                    self.tableView.backgroundView = self.emptyPlaylistBackgroundView()
                }
                return
            }

            let orderRule = self.storage.playlistOrder ?? .default 
            switch orderRule {
            case .none:
                break
            case .mostViewed, .recentViewed:
                var shaCache: [String: String] = [:]
                func sha(for channel: String) -> String {
                    if let sha = shaCache[channel] {
                        return sha
                    }
                    let sha = Data(SHA512.hash(data: channel.data(using: .utf8)!)).base64EncodedString()
                    shaCache[channel] = sha
                    return sha
                }
                let recent = self.storage.playlistOrder(playlist: name, rule: orderRule) ?? []
                let encrypted = self.pinData != nil // When true then `recent` contains SHA strings.
                var first: [Channel] = []
                for name in recent {
                    guard let channel = playlist.first(where: {
                        if encrypted {
                            sha(for: $0.name) == name
                        } else {
                            $0.name == name
                        }
                    }) else {
                        continue
                    }
                    first.append(channel)
                }
                let last = playlist.filter({
                    if encrypted {
                        !recent.contains(sha(for: $0.name))
                    } else {
                        !recent.contains($0.name)
                    }
                })
                playlist = first + last
            case .asc:
                playlist.sort(by: { $0.name < $1.name })
            case .desc:
                playlist.sort(by: { $0.name > $1.name })
            }
            
            self.orderedChannels = playlist

            var channels: [Row] = []
            var prefetch: [IndexPath] = []
            for (index, channel) in playlist.enumerated() {
                channels.append(Row(channel: channel))
                if index < 15 {
                    prefetch.append(.init(row: index, section: 0))
                }
            }
            
            DispatchQueue.main.async { [channels, prefetch] in
                self.reloadAfterDelayedFetch = true
                self.tableView(self.tableView, prefetchRowsAt: prefetch)

                var snapshot = self.dataSource.snapshot()
                snapshot.deleteAllItems()
                snapshot.appendSections([.main])
                snapshot.appendItems(channels, toSection: .main)
                self.dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
    }
    
    func emptyPlaylistBackgroundView() -> UIView {
        let view = UIView()
        let label = UILabel()
        label.text = NSLocalizedString("No channels found.", comment: "")
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        return view
    }

    func programmesLoadingIndicator(hidden: Bool) {
        programmesLoadingIndicator.superview?.superview?.isHidden = hidden
        programmesLoadingLabel.text = NSLocalizedString("Programmes loading text", comment: "")
        if hidden {
            programmesLoadingIndicator.stopAnimating()
        } else {
            programmesLoadingIndicator.startAnimating()
        }
    }
}

extension PlaylistViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard let channels = orderedChannels else {
            return
        }
        let reloadAfterDelayedFetch = reloadAfterDelayedFetch
        for path in indexPaths {
            let channel = channels[path.row]
            channelICO.icoFetch(for: channel) { [weak self] _, image in
                guard let image, let self else {
                    return
                }
                let uiImage = UIImage(cgImage: image)
                self.logosCache[path] = uiImage

                if reloadAfterDelayedFetch {
                    var snapshot = self.dataSource.snapshot()
                    snapshot.reloadItems([.init(channel: channel)])
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }

            DispatchQueue.main.async {
                guard self.isProgrammesAvailable else {
                    return
                }
                let rows: [Row] = indexPaths.map({ Row(channel: channels[$0.row]) })
                for path in indexPaths {
                    self.updateProgrammesInfo(path: path, skipListViewUpdate: true)
                }
                if reloadAfterDelayedFetch {
                    var snapshot = self.dataSource.snapshot()
                    snapshot.reloadItems(rows)
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
        if reloadAfterDelayedFetch {
            self.reloadAfterDelayedFetch = false
        }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        guard let channels = orderedChannels else {
            return
        }
        for path in indexPaths {
            let channel = channels[path.row]
            channelICO.icoCancel(for: channel)
        }
    }
}

extension PlaylistViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableViewHeight
    }
    
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext,
                   with coordinator: UIFocusAnimationCoordinator) {
        var isPreviewInFocus = false
        if let next = context.nextFocusedView,
           NSStringFromClass(type(of: next)).contains("AVFocusContainerView") {
            isPreviewInFocus = true
        }
        if isPreviewInFocus {
            if isFullScreen {
                shadowPreviewView.setShadow(.none)
            } else {
                shadowPreviewView.setShadow(.focused)
            }
        } else {
            shadowPreviewView.setShadow(.notFocused)
            self.currentFocusPath = context.nextFocusedIndexPath
            self.updateProgrammesInfo()
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)

        for press in presses {
            if press.type == .select {
                if let responder = press.responder,
                   NSStringFromClass(type(of: responder)).contains("AVFocusContainerView"),
                   let currentPlayingPath {
                    self.tableView(tableView, didSelectRowAt: currentPlayingPath)
                    tableView.scrollToRow(at: currentPlayingPath, at: .top, animated: false)
                }
                return
            }
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let channel = dataSource.itemIdentifier(for: indexPath) {
            let videoPlayer: ChannelPlayerViewController

            let container = ContentVC()
            container.delegate = self
    
            let overlay = overlayPlayer
            overlay?.willMove(toParent: nil)
            overlay?.view.removeFromSuperview()
            overlay?.removeFromParent()

            switch (storage.openVideoMode ?? .default) {
            case .previewScreen where overlay?.url != channel.channel.stream:
                videoPlayer = ChannelPlayerViewController.instantiate()
                videoPlayer.url = channel.channel.stream
                videoPlayer.loadViewIfNeeded()
                container.context = videoPlayer
                channelNameLabel.text = channel.channel.original
                
                containerWillDisappear(container)
                containerDidDisappear(container)
            default:
                if overlay?.url == channel.channel.stream {
                    videoPlayer = overlay!
                } else {
                    videoPlayer = ChannelPlayerViewController.instantiate()
                    videoPlayer.url = channel.channel.stream
                    videoPlayer.loadViewIfNeeded()
                    channelNameLabel.text = channel.channel.original
                }

                container.addChild(videoPlayer)
                container.view.addSubview(videoPlayer.view)
                container.context = videoPlayer
                videoPlayer.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    videoPlayer.view.topAnchor.constraint(equalTo: container.view.topAnchor),
                    videoPlayer.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor),
                    videoPlayer.view.leftAnchor.constraint(equalTo: container.view.leftAnchor),
                    videoPlayer.view.rightAnchor.constraint(equalTo: container.view.rightAnchor)
                ])
                videoPlayer.didMove(toParent: container)

                self.present(container, animated: true)
            }

            self.currentPlayingPath = indexPath
            self.overlayPlayer = videoPlayer
            
            // Always accumulate data for better ordering.
            for order in [LocalStorage.PlaylistOrder.recentViewed, .mostViewed] {
                switch order {
                case .recentViewed, .mostViewed:
                    if let _ = self.pinData {
                        // For secured data take SHA as it provides same output for
                        // the same input (ChaChaPoly generates different output for same input).
                        let data = Data(SHA512.hash(data: channel.channel.name.data(using: .utf8)!))
                        self.storage.addPlaylistOrder(channel: data.base64EncodedString(), playlist: playlist!.name, rule: order)
                    } else {
                        self.storage.addPlaylistOrder(channel: channel.channel.name, playlist: playlist!.name, rule: order)
                    }
                default:
                    break
                }
            }
        }
    }
}

extension PlaylistViewController: ContainerViewControllerDelegate {
    func containerWillAppear(_ container: ContainerViewController) {
        startFullScreenTime = CFAbsoluteTimeGetCurrent()
        isFullScreen = true
        shadowPreviewView.removeFromSuperview()
    }
    
    func containerDidAppear(_ container: ContainerViewController) {
    }
    
    func containerWillDisappear(_ container: ContainerViewController) {
        guard let container = container as? ContentVC,
              let playerVC = container.context else {
            return
        }
    
        playerVC.willMove(toParent: nil)
        playerVC.view.removeFromSuperview()
        playerVC.removeFromParent()
    
        let bounds = UIScreen.main.bounds
        self.addChild(playerVC)
        self.view.addSubview(playerVC.view)
        playerVC.view.translatesAutoresizingMaskIntoConstraints = true
        let width = bounds.width / 1.7
        let height = bounds.height / 1.7
        playerVC.view.frame = CGRect(
            x: bounds.width - width - view.safeAreaInsets.right,
            y: bounds.height - height - view.safeAreaInsets.bottom,
            width: width, height: height)
        playerVC.didMove(toParent: self)
    
        self.overlayPlayer = playerVC
        self.overlayPlayer?.debugView.text = nil

        view.insertSubview(shadowPreviewView, belowSubview: playerVC.view)
        shadowPreviewView.frame = playerVC.view.frame
    }
    
    func containerDidDisappear(_ container: ContainerViewController) {
        if isProgrammesAvailable, CFAbsoluteTimeGetCurrent() - startFullScreenTime > 60 * 15 {
            updateProgrammesVisibleCells()
        }
        isFullScreen = false
    }
}

private extension PlaylistViewController {

    var isProgrammesAvailable: Bool {
        return programmes != nil
    }

    func updateProgrammesVisibleCells() {
        guard isProgrammesAvailable else {
            return
        }
        reloadAfterDelayedFetch = true
        let prefetch: [IndexPath] = self.tableView.indexPathsForVisibleRows ?? []
        self.tableView(self.tableView, prefetchRowsAt: prefetch)
    }

    func updateProgrammesInfo() {
        if let current = currentFocusPath {
            updateProgrammesInfo(path: current, skipListViewUpdate: false)
        }
    }

    func updateProgrammesInfo(path: IndexPath, skipListViewUpdate: Bool) {
        guard isProgrammesAvailable else {
            return
        }
        if let item = dataSource.itemIdentifier(for: path) {
            if skipListViewUpdate == false {
                for subview in programmesStackView.arrangedSubviews {
                    programmesStackView.removeArrangedSubview(subview)
                    subview.removeFromSuperview()
                }
            }

            var index = NSNotFound

            var programmes = self.programmes?.list(for: item.channel)
            if programmes == nil {
                // Use HD version because from playlist data source some
                // channels do not have "HD" suffix, but in programmes
                // they do have it. And vice versa.
                let cache = hdFixCache[item.channel.id]
                let hd: Channel = cache ?? ChannelHDNameFixer(channel: item.channel)
                programmes = self.programmes?.list(for: hd)
                if cache == nil, programmes != nil {
                    self.hdFixCache[item.channel.id] = hd
                }
            }
            guard let programmes else {
                currentProgrammeNameCache[path] = nil
                return
            }
            var programmesDisplay: [ChannelProgramme.Programme] = []
            let now = Date()
            let prevHours = Calendar.current.date(byAdding: .hour, value: -3, to: now)!
            let nextDay = Calendar.current.date(byAdding: .hour, value: 16, to: now)!
            for programme in programmes.programmes {
                guard programme.start < nextDay, programme.end > prevHours else {
                    continue
                }
                programmesDisplay.append(programme)
                if  programme.start <= now {
                    index = programmesDisplay.count - 1
                }
            }

            // Drop programmes that already ended many hours ago.
            if index != NSNotFound, index > 2 {
                let drop = index - 2
                index = abs(drop - index)
                programmesDisplay = Array(programmesDisplay.dropFirst(drop))
            }
            // Reduce programmesDisplay to fit in screen height.
            if programmesDisplay.count > 20 {
                programmesDisplay = programmesDisplay.dropLast(programmesDisplay.count - 20)
            }

            if skipListViewUpdate == false {
                let list: [String] = programmesDisplay.map({
                    "\(Self.dateFormatter.string(from: $0.start)) - \(Self.dateFormatter.string(from: $0.end)): \($0.name)"
                })

                for (idx, line) in list.enumerated() {
                    let label = UILabel()
                    label.text = line
                    label.numberOfLines = 0
                    label.font = .systemFont(ofSize: 31, weight: .regular)
                    programmesStackView.addArrangedSubview(label)
                    if index == idx {
                        label.textColor = UIColor.systemGreen
                    }
                }
            }

            currentProgrammeNameCache[path] =
                index == NSNotFound ? nil : programmesDisplay[index].name
        }
    }

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()
}

private class ContentVC: ContainerViewController {
    weak var context: ChannelPlayerViewController?
}

private class ChannelHDNameFixer: Channel {
    let name: String
    let original: String
    let short: String
    let id: AnyHashable
    let stream: URL
    let group: String?
    let logo: URL?

    init(channel: Channel) {
        self.name = channel.name.hasSuffix(" HD")
            ? String(channel.name.dropLast(3)) : channel.name + " HD"
        self.original = self.name
        self.short = channel.short
        self.id = AnyHashable(self.name)
        self.stream = channel.stream
        self.group = channel.group
        self.logo = channel.logo
    }
}

private final class ShadowView: UIView {

    enum Shadow {
        case focused
        case notFocused
        case none
    }

    func setShadow(_ shadow: Shadow) {
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 16

        switch shadow {
        case .focused:
            layer.shadowColor = UIColor.white.cgColor
        case .notFocused:
            layer.shadowColor = UIColor.black.cgColor
        case .none:
            layer.shadowOpacity = 0
        }
    }
}

private final class DebugMenuDataProvider {

    private var timer: Timer

    init(onUpdate: @escaping (String) -> ()) {
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useMB, .useGB]
        fmt.countStyle = .memory

        self.timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [onUpdate] _ in
            DispatchQueue.global(qos: .utility).async {
                guard let stats = ObjCUtils.memStats() else {
                    return
                }
                let cpuLoad = Int(ObjCUtils.cpuUsage() * 100)
                let text = "RAM Stats: use: \(fmt.string(fromByteCount: Int64(stats.usedMem))), free: \(fmt.string(fromByteCount: Int64(stats.freeMem))), total: \(fmt.string(fromByteCount: Int64(stats.totalMem)))\nCPU load: \(cpuLoad)%"
                logger.debug("\(text)")

                DispatchQueue.main.async {
                    onUpdate(text)
                }
            }
        }
    }

    deinit {
        timer.invalidate()
        logger.info("deinit \(Self.self))")
    }
}