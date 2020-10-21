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
}

extension FileSystemManager {
    // Skip name validation. It's user's fault for invalid name's symbols.
    func download(file: URL, name: String) throws -> URL {
        checkMainThread()
        let filesDir = try prepareFS()
        let content = try Data(contentsOf: file);
        let destination = filesDir.appendingPathComponent(name, isDirectory: false)
        try? fileManager.removeItem(at: destination)
        try content.write(to: destination, options: [.atomic])
        return destination
    }
    
    func files() throws -> [URL] {
        checkMainThread()
        let root = try prepareFS()
        let attributes: [URLResourceKey] = [.isHiddenKey, .isRegularFileKey]
        let files = try fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys:attributes)
        return files.filter { url in
            guard let resources = try? url.resourceValues(forKeys: Set(attributes)),
                  let isHidden = resources.isHidden, !isHidden,
                  let isRegularFile = resources.isRegularFile, isRegularFile else {
                return false
            }
            return true
        }
    }
    
    func filesNames() throws -> [String] {
        try files().compactMap { url in
            url.lastPathComponent
                .components(separatedBy: ".").first
        }
    }
    
    func file(named: String) throws -> URL? {
        try files().filter { url in
            url.lastPathComponent
                .components(separatedBy: ".").first == named
        }.first
    }
    
    func remove(file: URL) throws {
        try fileManager.removeItem(at: file)
    }
}

private extension FileSystemManager {
    func prepareFS() throws -> URL {
        try fileManager.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
    }
    
    func checkMainThread() {
        if Thread.isMainThread {
            os_log(.info, "File system operation(s) is(are) ran on UI thread.")
        }
    }
}
