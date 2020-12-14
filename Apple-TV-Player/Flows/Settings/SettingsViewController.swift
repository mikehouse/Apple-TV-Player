//
//  SettingsViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 07.12.2020.
//

import UIKit
import Reusable
import Channels

final class SettingsViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private var tableView: UITableView!
    private lazy var dataSource = DataSource(tableView: tableView) { [unowned self] view, path, row in
        let cell = view.dequeueReusableCell(for: path, cellType: SettingsViewCell.self)
        cell.textLabel?.text = row.title
        return cell
    }
    
    var providers: [IpTvProvider] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView()
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems([.providers], toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
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
        }
    }
}

private extension SettingsViewController {
    enum Section: Hashable {
        case main
    }
    
    enum Row: Hashable {
        case providers
        
        var title: String {
            switch self {
            case .providers:
                return NSLocalizedString("List of Ip tv providers", comment: "")
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
    
    func makeBackgroundEmptyVew() -> UIView {
        UIView.make(title: NSLocalizedString(
            "No bundles available.", comment: ""))
    }
}
