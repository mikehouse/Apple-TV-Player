//
//  FileSystemManager.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 21.10.2020.
//

import Foundation
import os
import CryptoKit
import UIKit

extension UserDefaults {
    static var app: UserDefaults { .standard }
}

final class FileSystemManager {
    private let fileManager = FileManager.default
    private let localStorage: LocalStorage
    private let compressor = PiedPiper()
    private let nameSeparator = "."

    init(storage: UserDefaults = .app) {
        self.localStorage = LocalStorage(storage: storage)
    }
}

extension FileSystemManager {

    private var symmetricKey: SymmetricKey {
        let key: SymmetricKey
        if let keyData: Data = self.localStorage.getData(.symmetricKey, domain: .common) {
            key = SymmetricKey(data: keyData)
        } else {
            key = SymmetricKey(size: .bits256)
            let data = key.withUnsafeBytes { Data(Array($0)) }
            self.localStorage.add(data: data, for: .symmetricKey, domain: .common)
        }
        return key
    }

    @discardableResult
    func download(file: URL, playlist name: String, pin: String?) throws -> String {
        os_log(.debug, "downloading %s named %s", pin.map({ _ in "<>" }) ?? String(describing: file), name)
        let content = try Data(contentsOf: file);
        let compressed = try compressor.compress(data: content)

        if let pin {
            let key = symmetricKey
            let authenticating = hashed(pin: pin)
            let encryptedPlaylist = try ChaChaPoly.seal(compressed, using: key, authenticating: authenticating).combined
            let encryptedPlaylistURL = try ChaChaPoly.seal(file.absoluteString.data(using: .utf8)!, using: key, authenticating: authenticating).combined

            localStorage.add(data: encryptedPlaylist, for: name, domain: .playlist)
            localStorage.add(data: encryptedPlaylistURL, for: name, domain: .playlistURL)
            localStorage.add(data: authenticating, for: name, domain: .pin)
        } else {
            localStorage.add(data: compressed, for: name, domain: .playlist)
            localStorage.add(value: file.absoluteString, for: name, domain: .playlistURL)
        }

        return name
    }
    
    func playlists() -> [String] {
        return localStorage.domainKeys(.playlist)
    }

    func playlist(named: String) -> String? {
        playlists().first(where :{ name in
            name == named
        })
    }
    
    func url(named: String, pin: String?) throws -> URL? {
        if let pin {
            if let urlData: Data = localStorage.getData(named, domain: .playlistURL) {
                let key = symmetricKey
                let sealedBox = try ChaChaPoly.SealedBox(combined: urlData)
                let decryptedURL = try ChaChaPoly.open(sealedBox, using: key, authenticating: hashed(pin: pin))
                return String(data: decryptedURL, encoding: .utf8).flatMap(URL.init(string:))
            } else {
                return nil
            }
        } else {
            return (localStorage.getValue(named, domain: .playlistURL) as? String).flatMap(URL.init(string:))
        }
    }

    func content(of name: String, pin: String?) throws -> Data? {
        try content(of: name, pin: pin.map(hashed(pin:)))
    }

    func content(of name: String, pin: Data?) throws -> Data? {
        let data: Data?
        if let pin {
            if let playlistData: Data = localStorage.getData(name, domain: .playlist) {
                let key = symmetricKey
                let sealedBox = try ChaChaPoly.SealedBox(combined: playlistData)
                data = try ChaChaPoly.open(sealedBox, using: key, authenticating: pin)
            } else {
                data = nil
            }
        } else {
            data = localStorage.getData(name, domain: .playlist)
        }
        if let data {
            return try compressor.decompress(data: data)
        }
        return nil
    }

    func remove(playlist name: String) {
        localStorage.remove(for: name, domain: .playlist)
        localStorage.remove(for: name, domain: .playlistURL)
        localStorage.remove(for: name, domain: .pin)
    }

    func verify(pin: String, playlist name: String) -> Bool {
        guard let localHashedPin: Data = localStorage.getData(name, domain: .pin) else {
            return false
        }
        return hashed(pin: pin) == localHashedPin
    }

    func set(pin: String, playlist name: String) throws {
        guard let url = try url(named: name, pin: nil),
              let content = try content(of: name, pin: Optional<String>.none) else {
            return
        }
        let key = symmetricKey
        let authenticating = hashed(pin: pin)
        let compressed = try compressor.compress(data: content)
        let encryptedPlaylist = try ChaChaPoly.seal(compressed, using: key, authenticating: authenticating).combined
        let encryptedPlaylistURL = try ChaChaPoly.seal(url.absoluteString.data(using: .utf8)!, using: key, authenticating: authenticating).combined

        localStorage.add(data: encryptedPlaylist, for: name, domain: .playlist)
        localStorage.add(data: encryptedPlaylistURL, for: name, domain: .playlistURL)
        localStorage.add(data: authenticating, for: name, domain: .pin)
    }

    func pin(playlist name: String) -> Data? {
        localStorage.getData(name, domain: .pin)
    }

    func removePin(playlist name: String, pin: String) throws {
        guard let url = try url(named: name, pin: pin),
              let content = try content(of: name, pin: pin) else {
            return
        }
        let compressed = try! compressor.compress(data: content)
        localStorage.add(data: compressed, for: name, domain: .playlist)
        localStorage.add(value: url.absoluteString, for: name, domain: .playlistURL)
        localStorage.remove(for: name, domain: .pin)
    }

    func hashed(pin: String) -> Data {
        let salt = UIDevice.current.identifierForVendor?.uuidString ?? "0000-0000"
        os_log(.debug, "salt %s", salt)
        let target = "\(pin)-\(salt)"
        var sha256 = SHA256()
        sha256.update(data: target.data(using: .utf8)!)
        return Data(sha256.finalize())
    }
}
