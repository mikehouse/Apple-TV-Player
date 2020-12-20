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
    @IBOutlet private var programmesStackView: UIStackView!
    @IBOutlet private var timeLabel: UILabel!
    
    var playlist: Playlist?
    var programmes: IpTvProgrammesProvider?
    
    private var currentFocusPath: IndexPath?
    private var timeUpdateTimer: Timer?
    
    private lazy var channelICO: ChannelICOProvider = ChannelICO(locale: "ru")
    private lazy var dataSource = DataSource(tableView: self.tableView) { [unowned self] tableView, indexPath, row in
        let cell = tableView.dequeueReusableCell(
            for: indexPath, cellType: PlaylistChannelViewCell.self)
        cell.textLabel?.text = row.channel.name
        cell.imageView?.image = self.channelICO.ico(for: row.channel).map(UIImage.init(cgImage:))
        return cell
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        configureTableView()
        configureTimeLabel()
        loadPlaylist()
        programmes?.load { [weak self] error in
            if let error = error {
                os_log(.error, "\(error as NSObject)")
            } else {
                DispatchQueue.main.async {
                    self?.updateProgrammesInfo()
                }
            }
        }
    }
    
    deinit {
        os_log(.debug, "deinit %s", String(describing: self))
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
        tableView.dataSource = dataSource
    }
    
    func configureTimeLabel() {
        timeLabel.text = nil
        timeLabel.textColor = .tertiaryLabel
    
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
            guard let playlist = self.playlist?.channels, !playlist.isEmpty else {
                DispatchQueue.main.async {
                    self.tableView.backgroundView = self.emptyPlaylistBackgroundView()
                }
                return
            }
            
            var channels: [Row] = []
            for channel in playlist {
                let _ = self.channelICO.ico(for: channel) // fill the cache.
                channels.append(Row(channel: channel))
            }
            
            DispatchQueue.main.async { [channels] in
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
}

extension PlaylistViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext,
                   with coordinator: UIFocusAnimationCoordinator) {
        self.currentFocusPath = context.nextFocusedIndexPath
        self.updateProgrammesInfo()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let channel = dataSource.itemIdentifier(for: indexPath) {
            let videoPlayer = ChannelPlayerViewController.instantiate()
            videoPlayer.url = channel.channel.stream
            self.present(videoPlayer, animated: true)
        }
    }
}

private extension PlaylistViewController {
    func updateProgrammesInfo() {
        if let path = self.currentFocusPath, let item = dataSource.itemIdentifier(for: path) {
            self.currentFocusPath = path
            
            programmesStackView.arrangedSubviews.forEach(programmesStackView.removeArrangedSubview)
            programmesStackView.arrangedSubviews.forEach({$0.removeFromSuperview()})
            programmesStackView.subviews.forEach({$0.removeFromSuperview()})
    
            var index = NSNotFound
            
            let list: [String] = self.programmes?.list(for: item.channel) ?? []
            if let now = self.nowHourAndMinutesDate() {
                var hasEvening = false
                for (idx, line) in list.enumerated() {
                    let time = String(line[..<line.index(line.startIndex, offsetBy: 5)])
                    if !hasEvening { hasEvening = time.hasPrefix("2") }
                    let isAfterMidNight = time.hasPrefix("0")
                    guard var date = Self.dateFormatter.date(from: time) else { continue }
                    if hasEvening && isAfterMidNight {
                        date.addTimeInterval(60 * 60 * 24)
                    }
                    if now < date {
                        index = idx == 0 ? idx : idx - 1
                        break
                    }
                }
            }
            
            for (idx, line) in list.enumerated() {
                let label = UILabel()
                label.text = line
                label.numberOfLines = 0
                programmesStackView.addArrangedSubview(label)
                if index == idx {
                    label.textColor = UIColor.systemGreen
                }
            }
        }
    }
    
    func nowHourAndMinutesDate() -> Date? {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let minutes = Calendar.current.component(.minute, from: now)
        let time = String(format: "%.2d:%.2d", hour, minutes)
        return Self.dateFormatter.date(from: "\(time)")
    }
    
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()
}
