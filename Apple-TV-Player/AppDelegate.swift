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
        #if DEBUG
            let fileManager = FileManager.default
            if let dest = try? fileManager.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true),
               let playlist = Bundle.main.url(forResource: "plst", withExtension: "m3u") {
                let new = dest.appendingPathComponent(playlist.lastPathComponent, isDirectory: false)
                try? fileManager.removeItem(at: new)
                try? fileManager.copyItem(at: playlist, to: new)
            }
        #endif
        
        return true
    }
}

