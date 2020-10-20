//
//  HomeViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 21.10.2020.
//

import UIKit
import Reusable
import os

final class HomeViewController: UIViewController {

    @IBOutlet private var tableView: UITableView!
    
    private lazy var dataSource = DataSource(tableView: self.tableView) { tableView, indexPath, row in
        switch row {
        case .playlist(let name):
            let cell = tableView.dequeueReusableCell(
                for: indexPath, cellType: PlaylistCellView.self)
            return cell
        case .addPlaylist:
            let cell = tableView.dequeueReusableCell(
                for: indexPath, cellType: AddPlaylistCellView.self)
            return cell
        case .settings:
            let cell = tableView.dequeueReusableCell(
                for: indexPath, cellType: SettingsCellView.self)
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
            var items: [Section:[Row]] = [
                .addPlaylist: [.addPlaylist],
                .settings: [.settings],
                .playlists: []
            ]
            do {
                items[.playlists] = try fsManager.filesNames().map(Row.playlist)
            } catch {
                os_log(.error, "\(error as NSError)")
                RunLoop.main.perform { [unowned self, error] in
                    let alert = FailureViewController.make(error: error)
                    alert.addOkAction(title: NSLocalizedString("Ok", comment: ""), completion: nil)
                    present(alert, animated: true)
                }
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
    }
}
