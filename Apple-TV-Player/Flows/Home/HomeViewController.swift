//
//  HomeViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 21.10.2020.
//

import UIKit
import Reusable
import os
import Channels

final class HomeViewController: UIViewController {

    @IBOutlet private var tableView: UITableView!
    
    private lazy var dataSource = DataSource(tableView: self.tableView) { tableView, indexPath, row in
        switch row {
        case .playlist(let name):
            let cell = tableView.dequeueReusableCell(
                for: indexPath, cellType: PlaylistCellView.self)
            cell.textLabel?.text = name
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.register(cellType: SettingsCellView.self)
        tableView.register(cellType: AddPlaylistCellView.self)
        tableView.register(cellType: PlaylistCellView.self)

        reloadUI()
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
                .playlists: []
            ]
            do {
                items[.playlists] = try fsManager.filesNames().map(Row.playlist)
            } catch {
                os_log(.error, "\(error as NSError)")
                self.present(error: error)
            }
    
            DispatchQueue.main.async { [unowned self] in
                var snapshot = dataSource.snapshot()
                snapshot.appendSections(Section.allCases)
                snapshot.appendItems(items[.playlists] ?? [], toSection: .playlists)
                snapshot.appendItems(items[.addPlaylist] ?? [], toSection: .addPlaylist)
                snapshot.appendItems(items[.settings] ?? [], toSection: .settings)
                dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
    }
}

private extension HomeViewController {
    func present(error: Error) {
        RunLoop.main.perform { [unowned self, error] in
            let alert = FailureViewController.make(error: error)
            alert.addOkAction(title: NSLocalizedString("Ok", comment: ""), completion: nil)
            present(alert, animated: true)
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
}

private extension HomeViewController {
    enum Section: Hashable, CaseIterable {
        case playlists
        case addPlaylist
        case settings
    }
    
    enum Row: Hashable {
        case playlist(String) // name serves as unique id also.
        case addPlaylist
        case settings
    }
    
    final class DataSource: UITableViewDiffableDataSource<Section, Row> {
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        tableView.bounds.height / 6
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .playlist:
            break
        case .addPlaylist:
            let vc = AddPlaylistViewController(title: "",
                message: NSLocalizedString(
                    "Add playlist url (required) and its name (optional)", comment: ""),
                preferredStyle: .alert)
            vc.configure { [unowned self] url, name in
                DispatchQueue.global(qos: .userInitiated).async {
                    let message = "url: \(String(describing: url)), name: \(String(describing: name))"
                    os_log(.info, "\(message)")
                    guard let url = url else {
                        return
                    }
                    let name = name ?? url.lastPathComponent
                    
                    do {
                        DispatchQueue.main.async { self.setTableViewProgressView(enabled: true) }
                        let file = try fsManager.download(file: url, name: name)
                        do {
                            if try M3U(url: file).parse().isEmpty {
                                let error = NSError(domain: "com.tv.player", code: -1, userInfo: [
                                    NSLocalizedDescriptionKey: NSLocalizedString("No channels found.", comment: "")
                                ])
                                throw error
                            }
                        } catch {
                            try self.fsManager.remove(file: file)
                            throw error
                        }
                    } catch {
                        os_log(.error, "\(error as NSError)")
                        self.present(error: error)
                    }
    
                    DispatchQueue.main.async { self.setTableViewProgressView(enabled: false) }
                }
            }
            self.present(vc, animated: true)
        case .settings:
            break
        }
    }
}
