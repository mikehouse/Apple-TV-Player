//
//  FileSystemManager.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 21.10.2020.
//

import Foundation
import os

final class FileSystemManager {
    private let fileManager = FileManager.default
    private let localStorage = LocalStorage()
    private let compressor = PiedPiper()
    private let playlists = LocalStorage.Domain.playlist
    private let urls = LocalStorage.Domain.playlistURL
    private let nameSeparator = "."
}

extension FileSystemManager {
    @discardableResult
    func download(file: URL, name: String) throws -> String {
        checkMainThread()
        os_log(.error, "downloading %s named %s", String(describing: file), name)
        let content = try Data(contentsOf: file);
        let compressed = try compressor.compress(data: content)
        localStorage.add(data: compressed, for: name, domain: playlists)
        localStorage.add(value: file.absoluteString, for: name, domain: urls)
        return name
    }
    
    func files() throws -> [String] {
        checkMainThread()
        return localStorage.domainKeys(playlists)
    }
    
    func filesNames() throws -> [String] {
        try files().map(name(of:))
    }
    
    func file(named: String) throws -> String? {
        try files().first(where :{ url in
            self.name(of: url) == named
        })
    }
    
    func url(named: String) throws -> URL? {
        (localStorage.getValue(named, domain: urls) as? String).flatMap(URL.init(string:))
    }

    func content(of path: String) -> Data? {
        if let data = localStorage.getData(path, domain: playlists) {
            do {
                return try compressor.decompress(data: data)
            } catch {
                os_log(.error, "decompress error: %s", String(describing: error))
            }
        }
        return nil
    }
    
    private func name(of file: String) -> String {
        return file
    }
    
    func remove(file: String) throws {
        localStorage.remove(for: file, domain: playlists)
    }

    func remove(url: URL) throws {
        localStorage.remove(for: url, domain: urls)
    }
}

private extension FileSystemManager {
    func checkMainThread() {
        if Thread.isMainThread {
            os_log(.info, "File system operation(s) is(are) ran on UI thread.")
        }
    }
}
