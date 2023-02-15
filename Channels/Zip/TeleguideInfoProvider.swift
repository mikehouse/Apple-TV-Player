//
//  TeleguideInfoProvider.swift
//  Channels
//
//  Created by Mikhail Demidov on 22.01.2023.
//

import Foundation

final class TeleguideInfoXmlProvider {

    let url: URL

    init(url: URL) {
        self.url = url
    }

    // You should remove file after you're done with it.
    func info(_ completion: @escaping (Swift.Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async { [url] in
            let unzip = GunZipper(url: url)
            unzip.unzip { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let path):
                    guard FileManager.default.fileExists(atPath: path.path) else {
                        completion(.failure(NSError(domain: "file.not_exists.error", code: -1, userInfo: [
                            NSLocalizedDescriptionKey: path.path
                        ])))
                        return
                    }
                    completion(.success(path))
                }
            }
        }
    }
}
