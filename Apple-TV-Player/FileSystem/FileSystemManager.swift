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
    private let domain = LocalStorage.Domain.playlist
    private let nameSeparator = "."
}

extension FileSystemManager {
    @discardableResult
    func download(file: URL, name: String) throws -> URL {
        checkMainThread()
        os_log(.error, "downloading %s named %s", String(describing: file), name)
        let content = try Data(contentsOf: file);
        let url = URL(string: "playlist://\(name)")!
        let compressed = try compressor.compress(data: content)
        localStorage.add(data: compressed, for: url, domain: domain)
        return url
    }
    
    func files() throws -> [URL] {
        checkMainThread()
        return localStorage.domainKeysURLs(domain)
    }
    
    func filesNames() throws -> [String] {
        try files().map(name(of:))
    }
    
    func file(named: String) throws -> URL? {
        try files().first(where :{ url in
            self.name(of: url) == named
        })
    }
    
    func content(of path: URL) -> Data? {
        if let data = localStorage.getData(path, domain: domain) {
            do {
                return try compressor.decompress(data: data)
            } catch {
                os_log(.error, "decompress error: %s", String(describing: error))
            }
        }
        return nil
    }
    
    private func name(of file: URL) -> String {
        file.host ?? file.absoluteString
    }
    
    func remove(file: URL) throws {
        localStorage.remove(for: file, domain: domain)
    }
}

private extension FileSystemManager {
    func checkMainThread() {
        if Thread.isMainThread {
            os_log(.info, "File system operation(s) is(are) ran on UI thread.")
        }
    }
}
