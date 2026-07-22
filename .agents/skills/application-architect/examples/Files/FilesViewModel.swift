import FactoryKit
import SwiftUI

@Observable
final class FilesViewModel {

    @ObservationIgnored @Injected(\.filesService) private var filesService

    private(set) var list: [String] = []
    var isSelectingExportDirectory = false

    func updateList(_ path: URL) async {
        list = await filesService.list(path)
    }

    func selectExportDirectory() {
        isSelectingExportDirectory.toggle()
    }
}