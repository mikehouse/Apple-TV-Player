
import SwiftUI
import SwiftData
import FactoryKit

@Observable
final class AppleTVMultiplatformAppViewModel {

    @ObservationIgnored @Injected(\.databaseService) private var databaseService
    @ObservationIgnored @Injected(\.logger) private var logger
    private(set) var error: LocalizableError? {
        didSet {
            isErrorPresented = error != nil
        }
    }
    var isErrorPresented = false

    func handleIncomingFile(url: URL) -> Bool {
        let isSecureScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecureScoped {
                url.stopAccessingSecurityScopedResource()
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(PlaylistItem.self, from: data)
            guard decoded.name != nil, decoded.date != nil else {
                error = "Invalid playlist"
                return false
            }
            let fetch = FetchDescriptor<PlaylistItem>()
            guard try databaseService.mainContext.fetch(fetch)
                .first(where: { $0.identity == decoded.identity }) == nil else {
                error = "Playlist already exists"
                return false
            }
            databaseService.mainContext.insert(decoded)
            try databaseService.mainContext.save()
            logger.info("Playlist added", private: decoded.name!)
            return true
        } catch {
            logger.error(error)
            self.error = .init(error: error)
            return false
        }
    }
}
