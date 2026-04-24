import FactoryKit
import SwiftData
import SwiftUI

@Observable
final class PlaylistAddViewModel {

    @ObservationIgnored @Injected(\.playlistAddService) private var playlistAddService
    @ObservationIgnored @Injected(\.databaseService) private var databaseService
    @ObservationIgnored @Injected(\.logger) private var logger

    var name = ""
    var urlString = ""
    var pin = ""
    var urlTvg = ""
    var urlImg = ""
    var tvgLogo = ""
    private(set) var isLoading = false
    private(set) var progress: String = ""
    private(set) var errorMessage: String?
    var isShowingError = false

    var canAdd: Bool {
        !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func addPlaylist() async -> Bool {
        guard canAdd else {
            return false
        }

        isLoading = true
        errorMessage = nil
        isShowingError = false
        defer { isLoading = false }

        do {
            let log: [String] = [
                "Preparing playlist with name: \(name)",
                "URL: \(urlString)",
                "PIN: \(pin)",
                "URL TVG: \(urlTvg)",
                "URL IMG: \(urlImg)",
                "TVG Logo: \(tvgLogo)"
            ]
            logger.info("Create playlist with\n", private: log.joined(separator: "\n"))
            let prepared = try await playlistAddService.preparePlaylist(
                name: name,
                urlString: urlString,
                pin: pin,
                urlTvg: urlTvg,
                urlImg: urlImg,
                tvgLogo: tvgLogo
            ) { [weak self] _, step in
                switch step {
                case .start, .complete:
                    break
                default:
                    Task { @MainActor in
                        self?.progress = step.title
                    }
                }
            }

            if Task.isCancelled {
                logger.info("Playlist creation task cancelled")
                return false
            }

            let playlist = PlaylistItem(
                name: prepared.name,
                date: prepared.date,
                icon: prepared.icon,
                url: prepared.url,
                data: prepared.data,
                salt: prepared.salt,
                encrypted: prepared.encrypted,
                settings: .init(order: nil)
            )

            databaseService.mainContext.insert(playlist)
            try databaseService.mainContext.save()
            return true
        } catch {
            logger.error(error)
            databaseService.mainContext.rollback()
            errorMessage = errorMessage(for: error)
            isShowingError = true
            return false
        }
    }

    isolated deinit {
        logger.info("deinit of \(self)")
    }
}

private extension PlaylistAddViewModel {

    func errorMessage(for error: Swift.Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == CocoaError.fileReadNoSuchFile.rawValue {
            return "The playlist file could not be found."
        }

        return "\(error)"
    }
}
