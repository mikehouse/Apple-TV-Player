//
//  Zipper.swift
//  Channels
//
//  Created by Mikhail Demidov on 22.01.2023.
//

import Foundation
import GZIP

final class GunZipper {

    let url: URL

    init(url: URL) {
        self.url = url
    }

    func unzip(completion: @escaping (Swift.Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [url] in
            do {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
                var zipFileURL: URL = url
                if url.isFileURL == false {
                    logger.info("downloading \(url)")
                    let data: NSData = try NSData(contentsOf: url)
                    let path = tmp.appendingPathComponent(url.lastPathComponent)
                    logger.info("move to \(path)")
                    try data.write(to: path)
                    zipFileURL = path
                }

                guard let data = ((try NSData(contentsOf: zipFileURL)) as NSData).gunzipped() else {
                    throw NSError(domain: "gz.decode.error", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: url.path
                    ])
                }
                let unzipName = String(url.lastPathComponent.dropLast(url.pathExtension.count + 1))
                let result = tmp.appendingPathComponent(unzipName)
                try data.write(to: result)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
