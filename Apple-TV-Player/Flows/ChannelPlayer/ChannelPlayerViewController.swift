//
//  ChannelPlayerViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 14.11.2020.
//

import UIKit
import os
import Reusable
import AVFoundation
import AVKit

final class ChannelPlayerViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private var playerView: UIView!
    @IBOutlet private var errorLabel: UILabel!
    
    var url: URL?
    private var player: PlayerInterface = EmptyPlayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        if let url {
            os_log(.debug, "set channel to play from %s", String(describing: url))
            player = configureNativePlayer(url)
        } else {
            playerView.isHidden = true
            errorLabel.text = "No channel URL found."
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !player.isPlaying {
            player.play()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if player.isPlaying {
            player.pause()
        }
    }
    
    deinit {
        player.stop()
        os_log(.debug, "deinit %s", String(describing: self))
    }

    private func configureNativePlayer(_ url: URL) -> PlayerInterface {
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        let vc = AVPlayerViewController()
        vc.loadViewIfNeeded()

        addChild(vc)
        playerView.addSubview(vc.view)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vc.view.leftAnchor.constraint(equalTo: playerView.leftAnchor),
            vc.view.rightAnchor.constraint(equalTo: playerView.rightAnchor),
            vc.view.bottomAnchor.constraint(equalTo: playerView.bottomAnchor),
            vc.view.topAnchor.constraint(equalTo: playerView.topAnchor),
        ])
        vc.didMove(toParent: self)

        vc.player = player
        return NativePlayer(player: player)
    }
}

private protocol PlayerInterface {

    var isPlaying: Bool {get}

    func play()
    func pause()
    func stop()
}

private final class NativePlayer: PlayerInterface {
    private let player: AVPlayer

    init(player: AVPlayer) {
        self.player = player
    }

    var isPlaying: Bool { player.rate != 0.0 }
    func play() { player.play() }
    func pause() { player.pause() }
    func stop() { player.replaceCurrentItem(with: nil) }
}

private final class EmptyPlayer: PlayerInterface {
    var isPlaying: Bool { false }
    func play() { }
    func pause() { }
    func stop() { }
}