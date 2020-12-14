//
//  ProvidersListViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 29.11.2020.
//

import UIKit
import Reusable
import Channels

final class ProvidersListViewController: UIViewController, StoryboardBased {

    var providers: [IpTvProvider] = []
    
    @IBOutlet private var tableView: UITableView!
    private lazy var dataSource = DataSource(tableView: tableView) { [unowned self] view, path, row in
        let provider = self.providers[path.row]
        let cell = view.dequeueReusableCell(for: path, cellType: ProviderCellView.self)
        cell.textLabel?.text = provider.kind.name
        cell.imageView?.image = provider.kind.icon.map(UIImage.init(cgImage:))
        cell.accessoryType = self.storage.getValue(.current, domain: .common) == provider.kind.id ? .checkmark : .none
        return cell
    }
    private lazy var storage = LocalStorage()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureTableView()
        
        if providers.isEmpty {
            tableView.backgroundView = makeBackgroundEmptyVew()
            return
        }
        
        var snapshot = dataSource.snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(providers.map({ Row.provider(AnyHashable($0.kind)) }), toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

extension ProvidersListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let provider = providers[indexPath.row]
        RunLoop.current.perform {
            let vc = ProviderBundleViewController.instantiate()
            vc.provider = provider
            self.present(vc, animated: true)
            self.storage.add(value: provider.kind.id, for: .current, domain: .common)
            self.tableView.reloadData()
        }
    }
}

private extension ProvidersListViewController {
    enum Section: Hashable {
        case main
    }
    
    enum Row: Hashable {
        case provider(AnyHashable)
    }
    
    final class DataSource: UITableViewDiffableDataSource<Section, Row> {}
}

private extension ProvidersListViewController {
    func configureTableView() {
        tableView.register(cellType: ProviderCellView.self)
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
    }
    
    func makeBackgroundEmptyVew() -> UIView {
        UIView.make(title: NSLocalizedString(
            "No Ip Tv providers found.", comment: ""))
    }
}
