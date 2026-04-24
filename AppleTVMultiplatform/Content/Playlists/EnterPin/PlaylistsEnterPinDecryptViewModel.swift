
import SwiftUI
import SwiftData
import FactoryKit

@Observable
final class PlaylistsEnterPinDecryptViewModel {

    @ObservationIgnored @Injected(\.databaseService) private var databaseService
    @ObservationIgnored @Injected(\.playlistAddService) private var playlistAddService
    @ObservationIgnored @Injected(\.logger) private var logger
    private let identity: PlaylistItem.Identity
    var showAlert = false
    var message = ""

    init(identity: PlaylistItem.Identity) {
        self.identity = identity
    }

    var pin = ""

    func onPinInput() async -> PlaylistItem.Content? {
        do {
            logger.info("Receive to decrypt the pin", private: pin)
            let fetch = FetchDescriptor<PlaylistItem>()
            guard let playlist = (try databaseService.mainContext.fetch(fetch))
                .first(where: { $0.identity == identity }), playlist.encrypted else {
                return nil
            }
            guard let preparedPlaylist = PreparedPlaylist(playlist) else {
                return nil
            }
            logger.info("Start decrypting", private: identity)
            return try await playlistAddService.restorePlaylist(preparedPlaylist, pin: pin).content
        } catch {
            message = error.localizedDescription
            logger.error(error)
            showAlert = true
            return nil
        }
    }

    isolated deinit {
        logger.info("deinit of \(self)")
    }
}
