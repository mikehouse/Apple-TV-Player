//
//  ProviderBundleViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 29.11.2020.
//

import UIKit
import Reusable
import Channels

final class ProviderBundleViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private var tableView: UITableView!
    private lazy var dataSource = DataSource(tableView: tableView) { [unowned self] view, path, row in
        let bundle = self.provider!.bundles[path.row]
        let cell = view.dequeueReusableCell(for: path, cellType: ProviderBundleCellView.self)
        let bundles = self.storage.array(domain: .list(.provider(self.provider!.kind.id)))
        cell.textLabel?.text = bundle.name
        let baseBundles = self.provider!.baseBundles.map(\.id)
        let hasBundle = bundles.isEmpty ? baseBundles.contains(bundle.id) : bundles.contains(bundle.id)
        cell.accessoryType = hasBundle ? .checkmark : .none
        return cell
    }
    private lazy var storage = LocalStorage()
    
    var provider: IpTvProvider?
    
    private var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureTableView()
        
        guard let bundles = provider?.bundles, !bundles.isEmpty else {
            tableView.backgroundView = makeBackgroundEmptyVew()
            return
        }
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(bundles.map({ Row.bundle($0.id) }), toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

extension ProviderBundleViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let provider = self.provider!
        let bundle = provider.bundles[indexPath.row]
        let value = bundle.id
        let key: LocalStorage.Domain = .list(.provider(provider.kind.id))
        if self.storage.addArray(value: value, domain: key) {
            self.tableView.reloadData()
        } else {
            assert(self.storage.removeArray(value: value, domain: key))
            self.tableView.reloadData()
        }
    }
}

private extension ProviderBundleViewController {
    enum Section: Hashable {
        case main
    }
    
    enum Row: Hashable {
        case bundle(AnyHashable)
    }
    
    final class DataSource: UITableViewDiffableDataSource<Section, Row> {}
}

private extension ProviderBundleViewController {
    func configureTableView() {
        tableView.register(cellType: ProviderBundleCellView.self)
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    func makeBackgroundEmptyVew() -> UIView {
        UIView.make(title: NSLocalizedString(
            "No bundles available.", comment: ""))
    }
}
