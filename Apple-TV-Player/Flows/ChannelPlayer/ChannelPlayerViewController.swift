//
//  ChannelPlayerViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 14.11.2020.
//

import UIKit
import TVVLCKit
import Reusable
import AVFoundation
import AVKit

final class ChannelPlayerViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private var playerView: UIView!
    @IBOutlet private var errorLabel: UILabel!

    private lazy var overlayView: UIView = {
        let blurEffect = UIBlurEffect(style: .regular)
        let blurVIew = UIVisualEffectView(effect: blurEffect)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        blurVIew.contentView.addSubview(indicator)
        NSLayoutConstraint.activate([
            blurVIew.contentView.centerXAnchor.constraint(equalTo: indicator.centerXAnchor),
            blurVIew.contentView.centerYAnchor.constraint(equalTo: indicator.centerYAnchor)
        ])
        indicator.startAnimating()
        return blurVIew
    }()
    
    var url: URL?
    private var player: PlayerInterface = EmptyPlayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            #if targetEnvironment(simulator)
            // Since some Xcode version, native video player doesn't show an image (the sound works).
            self.player = configureVLCPlayer(url)
            #else
            let player = components.queryItems?.first(where: { $0.name == "player" })?.value ?? "native"
            os_log(.info, "set channel to play using %s player from %s", player, String(describing: url))
            if player == "vlc" {
                self.player = configureVLCPlayer(url)
            } else {
                self.player = configureNativePlayer(url)
            }
            #endif

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
        logger.info("deinit \(self)")
    }

    // Legacy.
    // There are freezes for 1080p (buffering issue).
    // That is why switched to use native player.
    private func configureVLCPlayer(_ url: URL) -> PlayerInterface {
        let mediaPlayer = VLCMediaPlayer()
        let media = VLCMedia(url: url)
        // https://stackoverflow.com/a/41961321/3614746
        let options: [String] = [
//                "network-caching=150",
//                "network-caching=3000",
            "clock-jitter=0",
            "clock-synchro=0",
            "drop-late-frames",
            "skip-frames"
        ]
        for option in options {
            media.addOption("--\(option)")
            media.addOption(":\(option)")
        }

        mediaPlayer.setDeinterlaceFilter(nil)
        mediaPlayer.adjustFilter.isEnabled = false
        mediaPlayer.media = media
        mediaPlayer.drawable = playerView

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            view.leftAnchor.constraint(equalTo: overlayView.leftAnchor),
            view.rightAnchor.constraint(equalTo: overlayView.rightAnchor),
            view.topAnchor.constraint(equalTo: overlayView.topAnchor),
            view.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor)
        ])

        return VlcPlayer(player: mediaPlayer, onPlay: { [weak self] in
            self?.overlayView.removeFromSuperview()
        }, onError: { [errorLabel=errorLabel!] error in
            DispatchQueue.main.async {
                errorLabel.text = "\(error)"
            }
        })
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
        return NativePlayer(player: player) { [errorLabel=errorLabel!] error in
            DispatchQueue.main.async {
                errorLabel.text = "\(error)"
            }
        }
    }
}

private protocol PlayerInterface {

    var isPlaying: Bool {get}
    var onError: ((Error) -> Void)? {get}

    func play()
    func pause()
    func stop()
}

private final class NativePlayer: PlayerInterface {
    private let player: AVPlayer
    private var observation: NSKeyValueObservation?
    var onError: ((Error) -> Void)?

    init(player: AVPlayer, onError: @escaping (Error) -> Void) {
        self.player = player
        self.onError = onError
    }

    var isPlaying: Bool { player.rate != 0.0 }
    func play() {
        switch player.status {
        case .readyToPlay:
            observation = nil
            player.play()
        case .failed:
            observation = nil
            onError?(NSError(domain: "failed", code: -1))
        default:
            if observation != nil {
                break
            }
            observation = player.observe(\.status, options: .new) {[weak self] _, _ in
                self?.play()
            }
        }
    }
    func pause() { player.pause() }
    func stop() { player.replaceCurrentItem(with: nil) }
}

private final class VlcPlayer: NSObject, PlayerInterface, VLCMediaPlayerDelegate {
    private let player: VLCMediaPlayer
    private let onPlay: () -> Void
    var onError: ((Error) -> Void)?

    init(player: VLCMediaPlayer, onPlay: @escaping () -> Void, onError: @escaping (Error) -> Void) {
        self.player = player
        self.onPlay = onPlay
        self.onError = onError
        super.init()
        player.delegate = self
    }

    var isPlaying: Bool { player.isPlaying }
    func play() { player.play() }
    func pause() { player.pause() }
    func stop() { player.stop() }

    func mediaPlayerStateChanged(_ aNotification: Notification) {
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        player.delegate = nil
        DispatchQueue.main.async {
            self.onPlay()
        }
    }
    func mediaPlayerTitleChanged(_ aNotification: Notification) {
    }
    func mediaPlayerChapterChanged(_ aNotification: Notification) {
    }
    func mediaPlayerSnapshot(_ aNotification: Notification) {
    }
    func mediaPlayerStartedRecording(_ player: VLCMediaPlayer) {
    }
    func mediaPlayer(_ player: VLCMediaPlayer, recordingStoppedAtPath path: String) {
    }
}

private final class EmptyPlayer: PlayerInterface {
    var isPlaying: Bool { false }
    var onError: ((Error) -> Void)?
    func play() { }
    func pause() { }
    func stop() { }
}