//
//  SettingsViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import UIKit
import Reusable
import Channels
import SwiftUI

final class SettingsViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private var tableView: UITableView!
    private lazy var dataSource = DataSource(tableView: tableView) { [unowned self] view, path, row in
        let cell = view.dequeueReusableCell(for: path, cellType: SettingsViewCell.self)
        cell.textLabel?.text = row.title
        if Row(rawValue: path.row) == .players {
            cell.detailTextLabel?.text = self.storage.getPlayer()?.title
        } else {
            cell.detailTextLabel?.text = nil
        }
        return cell
    }
    
    var providers: [IpTvProvider] = []
    private lazy var storage = LocalStorage(storage: .app)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView()
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems([.providers, .players], toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
    }
}

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch self.dataSource.itemIdentifier(for: indexPath)! {
        case .providers:
            let vc = ProvidersListViewController.instantiate()
            vc.providers = providers
            present(vc, animated: true)
        case .players:
            let view = SettingsPlayersView(storage: storage)
            let vc = UIHostingController(rootView: view)
            present(vc, animated: true)
        }
    }
}

private extension SettingsViewController {
    enum Section: Hashable {
        case main
    }
    
    enum Row: Int, Hashable {
        case providers
        case players

        var title: String {
            switch self {
            case .providers:
                return NSLocalizedString("List of Ip tv providers", comment: "")
            case .players:
                return NSLocalizedString("Player", comment: "")
            }
        }
    }
    
    final class DataSource: UITableViewDiffableDataSource<Section, Row> {}
}

private extension SettingsViewController {
    func configureTableView() {
        tableView.register(cellType: SettingsViewCell.self)
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
    }
}
