
import SwiftUI
import FactoryKit
import SwiftData

@Observable
final class PlaylistsViewModel {

    @ObservationIgnored @Injected(\.databaseService) private var databaseService
    @ObservationIgnored @Injected(\.playlistAddService) private var playlistAddService
    @ObservationIgnored @Injected(\.playlistService) private var playlistService
    @ObservationIgnored @Injected(\.logger) private var logger
    var playlists: [PlaylistItem] = []
    var selectedPlaylist: PlaylistItem?

    func updatePlaylists() {
        do {
            logger.info("Update playlists")
            let fetch = FetchDescriptor<PlaylistItem>(
                sortBy: [.init(\.date, order: .reverse)]
            )
            self.playlists = try databaseService.mainContext.fetch(fetch)
                .filter({ $0.date != nil && $0.name != nil })
        } catch {
            logger.error(error)
            self.playlists = []
        }
    }

    func deletePlaylist(_ playlist: PlaylistItem) {
        if let identity = playlist.identity {
            logger.info("Delete playlist", private: identity)
        }
        let preparedPlaylist = PreparedPlaylist(playlist)
        let reloadCurrent = playlist.identity == selectedPlaylist?.identity
        databaseService.mainContext.delete(playlist)
        try? databaseService.mainContext.save()
        if reloadCurrent {
            selectedPlaylist = nil
        }
        updatePlaylists()
        Task.detached { [self] in
            if let preparedPlaylist {
                if let restored = try? await playlistAddService.restorePlaylist(preparedPlaylist, pin: nil) {
                    await playlistService.clearCache(for: restored.content)
                }
            }
        }
    }

    func updateSelection(_ selection: PlaylistItem.Identity?) {
        guard let selection else {
            logger.info("Clear playlist selection")
            self.selectedPlaylist = nil
            return
        }
        logger.info("Select playlist", private: selection)
        let fetch = FetchDescriptor<PlaylistItem>()
        self.selectedPlaylist = try? databaseService.mainContext.fetch(fetch)
            .first(where: { $0.identity == selection })
    }

    func onPlaylistSelection() -> PlaylistItem.Identity? {
        let playlist = selectedPlaylist
        guard let name = playlist?.name,
              let date = playlist?.date else { return nil }
        return PlaylistItem.Identity(name: name, date: date)
    }

    isolated deinit {
        logger.info("deinit of \(self)")
    }
}
