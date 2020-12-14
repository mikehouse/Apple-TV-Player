//
//  AppDelegate.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 16.10.2020.
//

import UIKit
import os

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        /*#if DEBUG
            let fileManager = FileSystemManager()
            if let playlist = Bundle.main.url(forResource: "plst", withExtension: "m3u") {
                do {
                    try fileManager.download(file: playlist, name: "2090000.ru")
                } catch {
                    os_log(.error, "playlist download error: %s", String(describing: error))
                }
            }
        #endif*/
         print(FileManager.default.temporaryDirectory.deletingLastPathComponent())
        return true
    }
}

