//
//  PlaylistViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 14.11.2020.
//

import UIKit
import Reusable
import os
import Channels

final class PlaylistViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private var tableView: UITableView!
    
    var playlist: M3U?
    
    private lazy var dataSource = DataSource(tableView: self.tableView) { tableView, indexPath, row in
        let cell = tableView.dequeueReusableCell(
            for: indexPath, cellType: PlaylistChannelViewCell.self)
        cell.textLabel?.text = row.title
        return cell
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        configureTableView()
        loadPlaylist()
    }
    
    deinit {
        os_log(.debug, "deinit %s", String(describing: self))
    }
}

private extension PlaylistViewController {
    enum Section: Hashable {
        case channels(String?)
        func has(_ str: String?) -> Bool {
            switch self {
            case .channels(let s):
                return s == str
            }
        }
    }
    struct Row: Hashable {
        let channel: URL
        let title: String
    
        func hash(into hasher: inout Hasher) {
            hasher.combine(title)
        }
    
        static func ==(lhs: Row, rhs: Row) -> Bool {
            return lhs.title == rhs.title
        }
    }
}

private extension PlaylistViewController {
    final class DataSource: UITableViewDiffableDataSource<Section, Row> {
        var sectionsTitles: [String?] = []
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            sectionsTitles[section] ?? NSLocalizedString("Others", comment: "")
        }
    }
}

private extension PlaylistViewController {
    func configureTableView() {
        tableView.register(cellType: PlaylistChannelViewCell.self)
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
    
    func loadPlaylist() {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let playlist = self.playlist?.items, !playlist.isEmpty else {
                DispatchQueue.main.async {
                    self.tableView.backgroundView = self.emptyPlaylistBackgroundView()
                }
                return
            }
            
            var sections: [Section] = [] // to keep order in dict.
            var channels: [Section:[Row]] = [:]
            var titles: [String?] = []
            
            for channel in playlist {
                let row = Row(channel: channel.url, title: channel.title)
                if let section = sections.first(where: { $0.has(channel.group) }) {
                    channels[section] = (channels[section] ?? []) + [row]
                } else {
                    let section = Section.channels(channel.group)
                    sections.append(section)
                    channels[section] = [row]
                    titles.append(channel.group)
                }
            }
            
            DispatchQueue.main.async { [sections, channels, titles] in
                var snapshot = self.dataSource.snapshot()
                snapshot.deleteAllItems()
                snapshot.appendSections(sections)
                for section in sections {
                    snapshot.appendItems(channels[section] ?? [], toSection: section)
                }
                self.dataSource.sectionsTitles = titles
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
}

extension PlaylistViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        tableView.bounds.height / 10
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let channel = dataSource.itemIdentifier(for: indexPath) {
            let videoPlayer = ChannelPlayerViewController.instantiate()
            videoPlayer.url = channel.channel
            self.present(videoPlayer, animated: true)
        }
    }
}
