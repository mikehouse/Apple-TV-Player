//
//  ChannelPlayerViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 14.11.2020.
//

import UIKit
import os
import TVVLCKit
import Reusable

final class ChannelPlayerViewController: UIViewController, StoryboardBased {
    
    @IBOutlet private var playerView: UIView!
    @IBOutlet private var blurView: UIView!
    @IBOutlet private var blurViewLabel: UILabel!
    @IBOutlet private var errorLabel: UILabel!
    
    var url: URL?
    private lazy var mediaPlayer = VLCMediaPlayer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        if let url = self.url {
            os_log(.debug, "set channel to play from %s", String(describing: url))
            mediaPlayer.media = VLCMedia(url: url)
            mediaPlayer.drawable = playerView
            mediaPlayer.delegate = self
            blurViewLabel.text = url.absoluteString
        } else {
            blurViewLabel.text = ""
            playerView.isHidden = true
            errorLabel.text = "No channel URL found."
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !mediaPlayer.isPlaying {
            mediaPlayer.play()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
        }
    }
    
    deinit {
        mediaPlayer.stop()
        os_log(.debug, "deinit %s", String(describing: self))
    }
}

extension ChannelPlayerViewController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification!) {
    }
    
    func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        mediaPlayer.delegate = nil
        DispatchQueue.main.async {
            if (!self.blurView.isHidden) {
                self.blurView.isHidden = true
            }
        }
    }
    
    func mediaPlayerTitleChanged(_ aNotification: Notification!) {
    }
    
    func mediaPlayerChapterChanged(_ aNotification: Notification!) {
    }
    
    func mediaPlayerSnapshot(_ aNotification: Notification!) {
    }
    
    func mediaPlayerStartedRecording(_ player: VLCMediaPlayer!) {
    }
    
    func mediaPlayer(_ player: VLCMediaPlayer!, recordingStoppedAtPath path: String!) {
    }
}
