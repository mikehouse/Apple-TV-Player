//
//  HomeViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 21.10.2020.
//

import UIKit
import Reusable
import Channels

final class HomeViewController: UIViewController {

    @IBOutlet private var tableView: UITableView!

    private var playlistCache: [String:PlaylistItem] = [:]
    
    private lazy var dataSource = DataSource(tableView: self.tableView) { tableView, indexPath, row in
        switch row {
        case .playlist(let name):
            let cell = tableView.dequeueReusableCell(
                for: indexPath, cellType: PlaylistCellView.self)
            cell.textLabel?.text = name
            return cell
        case .providers(let provider):
            let cell = tableView.dequeueReusableCell(
                for: indexPath, cellType: SelectProviderCellView.self)
            cell.textLabel?.text = provider.name
            cell.imageView?.image = provider.icon.map(UIImage.init(cgImage:))
            return cell
        case .addPlaylist:
            let cell = tableView.dequeueReusableCell(
                for: indexPath, cellType: AddPlaylistCellView.self)
            cell.textLabel?.text = NSLocalizedString("Add playlist", comment: "")
            cell.imageView?.image = UIImage(systemName: "square.and.pencil")
            return cell
        case .settings:
            let cell = tableView.dequeueReusableCell(
                for: indexPath, cellType: SettingsCellView.self)
            cell.textLabel?.text = NSLocalizedString("Settings", comment: "")
            cell.imageView?.image = UIImage(systemName: "gear")
            return cell
        }
    }
    private let fsManager = FileSystemManager()
    private var providers: [IpTvProvider] = []
    private let storage = LocalStorage()
    private var handlingCellLongTap = false
    private var highlightingStarted = CFAbsoluteTimeGetCurrent()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.register(cellType: SettingsCellView.self)
        tableView.register(cellType: AddPlaylistCellView.self)
        tableView.register(cellType: PlaylistCellView.self)
        tableView.register(cellType: SelectProviderCellView.self)

        reloadUI()
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)

        for press in presses {
            if press.type == .playPause {
                if let cell: UITableViewCell = press.responder as? PlaylistCellView ?? press.responder as? SelectProviderCellView {
                    if let indexPath = tableView.indexPath(for: cell) {
                        handlingCellLongTap = true
                        tableView(tableView, didSelectRowAt: indexPath)
                    }
                }
                return
            }
        }
    }
}

private extension HomeViewController {
    func reloadUI() {
        DispatchQueue.main.async { [unowned self] in
            var snapshot = dataSource.snapshot()
            snapshot.deleteAllItems()
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        DispatchQueue.global(qos: .userInitiated).async { [unowned self] in
            // Skip any local caches to reduce complexity,
            // always reload from the file system.
            var items: [Section: [Row]] = [
                .addPlaylist: [.addPlaylist],
                .settings: [.settings],
                .playlists: [],
                .providers: []
            ]
            do {
                self.providers = try IpTvProviderKind.builtInProviders().map(IpTvProviders.kind(of:))
                items[.providers] = self.providers.map({ Row.providers($0.kind) })
            } catch {
                logger.error("\(error)")
                self.present(error: error)
            }
            items[.playlists] = fsManager.playlists().sorted().map(Row.playlist)
    
            DispatchQueue.main.async { [unowned self] in
                var snapshot = dataSource.snapshot()
                snapshot.appendSections(Section.allCases)
                snapshot.appendItems(items[.playlists] ?? [], toSection: .playlists)
                snapshot.appendItems(items[.providers] ?? [], toSection: .providers)
                snapshot.appendItems(items[.addPlaylist] ?? [], toSection: .addPlaylist)
                snapshot.appendItems(items[.settings] ?? [], toSection: .settings)
                dataSource.apply(snapshot, animatingDifferences: true)
    
                self.navigateToLatestProvider()
            }
        }
    }
}

private extension HomeViewController {
    func present(error: Error) {
        DispatchQueue.main.async {
            let alert = FailureViewController.make(error: error)
            alert.addOkAction(title: NSLocalizedString("Ok", comment: ""), completion: nil)
            self.present(alert, animated: true)
        }
    }
    
    func present(on onError: () throws -> Void) {
        do {
            try onError()
        } catch {
            self.present(error: error)
        }
    }

    func setTableViewProgressView(enabled: Bool) {
        if enabled {
            var snapshot = dataSource.snapshot()
            snapshot.deleteAllItems()
            dataSource.apply(snapshot, animatingDifferences: false)
            tableView.backgroundView = progressBackgroundView()
        } else {
            tableView.backgroundView = nil
            reloadUI()
        }
    }
    
    func progressBackgroundView() -> UIView {
        let view = UIView()
        let progress = UIActivityIndicatorView(style: .large)
        view.addSubview(progress)
        progress.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progress.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progress.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        progress.startAnimating()
        return view
    }
    
    @discardableResult
    func navigateToLatestProvider() -> Bool {
        if let provider = self.storage.getValue(.current, domain: .common),
           let item = IpTvProviderKind.builtInProviders().first(where: { $0.id == provider }) {
            let row = Row.providers(item)
            let snapshot = dataSource.snapshot()
            if let section = snapshot.indexOfSection(.providers),
               let row = snapshot.indexOfItem(row) {
                let path = IndexPath(row: row, section: section)
                navigate(to: path)
            }
        }
        return false
    }
}

private extension HomeViewController {
    enum Section: Hashable, CaseIterable {
        case playlists
        case providers
        case addPlaylist
        case settings
    }
    
    enum Row: Hashable {
        case playlist(String) // name serves as unique id also.
        case providers(IpTvProviderKind)
        case addPlaylist
        case settings
    }
    
    final class DataSource: UITableViewDiffableDataSource<Section, Row> {
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = self.dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .providers(let provider) where handlingCellLongTap:
            let actionVC = ActionPlaylistViewController()
            actionVC.resetPlaylistOrderAction = { [weak self] in
                self?.storage.removePlaylistOrder(playlist: provider.name)
            }            
            self.present(actionVC, animated: true)
            handlingCellLongTap = false
            return
        case .playlist(let name) where handlingCellLongTap:
            let actionVC = ActionPlaylistViewController()
            if let _ = playlistCache[name] {
                actionVC.removeCacheAction = { [unowned self] in
                    playlistCache.removeValue(forKey: name)
                }
            }
            actionVC.deleteAction = { [unowned self] in
                DispatchQueue.global(qos: .userInteractive).async {
                    self.fsManager.remove(playlist: name)
                    self.playlistCache.removeValue(forKey: name)
                    DispatchQueue.main.async {
                        self.reloadUI()
                    }
                }
            }
            actionVC.resetPlaylistOrderAction = { [weak self] in
                self?.storage.removePlaylistOrder(playlist: name)
            }
            if self.fsManager.pin(playlist: name) == nil {
                actionVC.setPinAction = { [unowned self] in
                    let view = SetPinViewController()
                    view.configure { [self] set, pin in
                        guard set, let pin, pin.isEmpty == false else {
                            return
                        }
                        present(on: { try self.fsManager.set(pin: pin, playlist: name) })
                    }
                    self.present(view, animated: true)
                }
            } else {
                actionVC.removePinAction = { [unowned self] in
                    let view = DeletePinViewController()
                    view.configure { [self] delete, pin in
                        guard delete, let pin else {
                            return
                        }
                        guard self.fsManager.verify(pin: pin, playlist: name) else {
                            self.present(error: NSError(domain: "pin.invalid.domain", code: -1, userInfo: [
                                NSLocalizedDescriptionKey: NSLocalizedString("Pin code is invalid.", comment: "")
                            ]))
                            return
                        }
                        present(on: { try self.fsManager.removePin(playlist: name, pin: pin) })
                    }
                    self.present(view, animated: true)
                }
            }
            actionVC.updateAction = { [unowned self] in
                let updateAction: (String?) -> Void = { pin in
                    DispatchQueue.main.async {
                        self.setTableViewProgressView(enabled: true)
                    }
                    DispatchQueue.global(qos: .userInitiated).async { [self] in
                        do {
                            guard let url = try fsManager.url(named: name, pin: pin) else {
                                throw NSError(domain: "playlist.not-found.domain", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: "No URL found for playlist '\(name)'"
                                ])
                            }
                            try self.fsManager.download(file: url, playlist: name, pin: pin) { data in
                                // Do not want to rewrite old playlist with new invalid one.
                                guard !data.isEmpty,
                                      let string = String(data: data, encoding: .utf8) else {
                                    return false
                                }
                                return string.components(separatedBy: .newlines).count > 1
                            }
                            self.playlistCache.removeValue(forKey: name)
                            DispatchQueue.main.async {
                                self.setTableViewProgressView(enabled: false)
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.present(error: error)
                                self.setTableViewProgressView(enabled: false)
                            }
                        }
                    }
                }
                if fsManager.pin(playlist: name) != nil {
                    let view = VerifyPinViewController()
                    view.configure { cancelled, pin in
                        guard !cancelled,
                              pin.map({ self.fsManager.verify(pin: $0, playlist: name) }) ?? true else {
                            return
                        }
                        updateAction(pin)
                    }
                    self.present(view, animated: true)
                } else {
                    updateAction(nil)
                }
            }
            self.present(actionVC, animated: true)
            handlingCellLongTap = false
            return
        default:
            break
        }
        navigate(to: indexPath)
    }
    
    func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
        highlightingStarted = CFAbsoluteTimeGetCurrent()
    }
    
    func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) {
        handlingCellLongTap = CFAbsoluteTimeGetCurrent() - highlightingStarted > 1.0
    }
    
    private func navigate(to indexPath: IndexPath, pin: Data? = nil) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .playlist(let name):
            func present(playlist: PlaylistItem) {
                let playlistVC = PlaylistViewController.instantiate()
                playlistVC.playlist = playlist
                playlistVC.pinData = pin
                self.present(playlistVC, animated: true) {
                    self.setTableViewProgressView(enabled: false)
                    logger.info("did open playlist \(name)")
                }
            }
            if let hashedPin = fsManager.pin(playlist: name) {
                guard let pin else {
                    let view = VerifyPinViewController()
                    view.configure { [unowned self] cancelled, pin in
                        guard !cancelled else {
                            return
                        }
                        navigate(to: indexPath, pin: pin.map(self.fsManager.hashed(pin:)) ?? Data())
                    }
                    self.present(view, animated: true)
                    return
                }
                guard pin == hashedPin else {
                    self.present(error: NSError(domain: "pin.invalid.domain", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: NSLocalizedString("Pin code is invalid.", comment: "")
                    ]))
                    return
                }
            }
            if let playlist = self.playlistCache[name] {
                present(playlist: playlist)
                return
            }
            DispatchQueue.global().async {
                guard let name = self.fsManager.playlist(named: name) else {
                    return
                }
                DispatchQueue.main.async {
                    self.setTableViewProgressView(enabled: true)
                }
                
                do {
                    guard let data = try self.fsManager.content(of: name, pin: pin) else {
                        return
                    }
                    // TODO: add ability for top tag `#EXTM3U` read image by name (from channel bundle) | from URL.
                    let tvProvider = try IpTvProviders.kind(of: .dynamic(m3u: data, name: name))
                    let playlist = PlaylistItem(channels: tvProvider.bundles.flatMap({ $0.playlist.channels }), name: name)
                    self.playlistCache[name] = playlist

                    DispatchQueue.main.async {
                        present(playlist: playlist)
                    }
                } catch {
                    self.present(error: error)
                    DispatchQueue.main.async {
                        self.setTableViewProgressView(enabled: false)
                    }
                }
            }
        case .providers(let providerKind):
            DispatchQueue.global(qos: .userInitiated).async {
                let provider = self.providers.first(where: { $0.kind.id == providerKind.id })!
                let bundlesIds = self.storage.array(domain: .list(.provider(providerKind.id)))
                let bundles = provider.bundles.filter({ bundlesIds.contains($0.id) })
                let bundlesForSure = bundles.isEmpty ? provider.baseBundles : bundles
                let channels: [Channel] = bundlesForSure.flatMap({ $0.playlist.channels })
                let playlist = PlaylistItem(channels: channels, name: provider.kind.name)
                DispatchQueue.main.async {
                    let playlistVC = PlaylistViewController.instantiate()
                    playlistVC.playlist = playlist
                    playlistVC.programmes = IpTvProgrammesProviders.make(for: provider.kind)
                    self.present(playlistVC, animated: true)
                }
            }
        case .addPlaylist:
            let vc = AddPlaylistViewController(title: "",
                message: NSLocalizedString(
                    "Add playlist url (required) and its name (optional)", comment: ""),
                preferredStyle: .alert)
            vc.configure { [unowned self] url, name, pin in
                DispatchQueue.global(qos: .userInitiated).async { [self] in
                    logger.info("adding playlist \(name ?? "") for url \(pin.map({ _ in "<>" }) ?? url?.absoluteString ?? "")")
                    guard let url = url else {
                        return
                    }
                    let name = name ?? url.lastPathComponent
                    
                    do {
                        DispatchQueue.main.async {
                            self.setTableViewProgressView(enabled: true)
                        }
                        let name = try fsManager.download(file: url, playlist: name, pin: pin)
                        do {
                            if try M3U(data: fsManager.content(of: name, pin: pin)!).parse().isEmpty {
                                let error = NSError(domain: "com.tv.player", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: NSLocalizedString("No channels found.", comment: "")
                                ])
                                throw error
                            }
                            if let pin {
                                present(on: { try self.fsManager.set(pin: pin, playlist: name) })
                            }
                        } catch {
                            self.fsManager.remove(playlist: name)
                            throw error
                        }
                    } catch {
                        logger.error("\(error)")
                        self.present(error: error)
                    }
                    
                    DispatchQueue.main.async {
                        self.setTableViewProgressView(enabled: false)
                    }
                }
            }
            self.present(vc, animated: true)
        case .settings:
            let vc = SettingsViewController.instantiate()
            vc.providers = self.providers
            self.present(vc, animated: true)
        }
    }
    
    private struct PlaylistItem: Playlist { 
        let channels: [Channel]
        let name: String 
    }
}
