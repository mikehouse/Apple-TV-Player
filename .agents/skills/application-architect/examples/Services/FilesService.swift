import Foundation
import FactoryKit

protocol FilesServiceInterface: AnyObject {

    func list(_ path: URL) async -> [String]
}

actor FilesService: FilesServiceInterface {

    private let fileManager = FileManager.default

    func list(_ path: URL) async -> [String] {
        (try? fileManager.contentsOfDirectory(atPath: path.path)) ?? []
    }
}

extension FactoryKit.Container {

    @MainActor
    var filesService: Factory<FilesServiceInterface> {
        self { FilesService() }.singleton
    }
}