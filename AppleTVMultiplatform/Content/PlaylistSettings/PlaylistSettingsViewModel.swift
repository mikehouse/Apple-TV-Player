
import Foundation
import FactoryKit
import SwiftUI
import SwiftData

@Observable
final class PlaylistSettingsViewModel {

    @ObservationIgnored @Injected(\.databaseService) private var databaseService
    @ObservationIgnored @Injected(\.playlistService) private var playlistService
    @ObservationIgnored @Injected(\.playlistAddService) private var playlistAddService
    @ObservationIgnored @Injected(\.logger) private var logger

    let identity: PlaylistItem.Identity
    private var playlist: PlaylistItem?

    var order: PlaylistSettingsItem.StreamListOrder = .none
    var pinEnabled = false
    var snapshot: (PlaylistSettingsItem.StreamListOrder, Bool, Bool, Bool, Bool)?
    var dataChanged = false
    var showPinCodeDecryptView = false
    var showPinCodeEncryptView = false
    var showPinCodeReEncryptView = false
    var showPinCodeDecryptProgramGuideView = false
    var showPinCodeDecryptPlaylistView = false
    var isPlaylistFileImporterPresented = false
    var selectedPlaylistFileURL: URL?
    var playlistDecryptedContent: PlaylistItem.Content?
    var playlistUpdateContent: PlaylistItem.Content?
    var pin: String = ""
    var progressText: StringIdentifiable?
    var error: LocalizableError?

    private(set) var progress = false
    private var pinChangesProgrammatically = false
    private var didUpdateProgramGuide = false
    private var didUpdatePlaylist = false

    init(identity: PlaylistItem.Identity) {
        self.identity = identity
        let fetch = FetchDescriptor<PlaylistItem>()
        playlist = (try? databaseService.mainContext.fetch(fetch))?
            .first(where: { $0.identity == identity })
        order = playlist?.settings?.orderType ?? .none
        pinEnabled = playlist?.encrypted ?? false
        if playlist?.settings == nil {
            playlist?.settings = PlaylistSettingsItem(order: nil)
        }
        snapshot = makeSnapshot()
    }

    private func updateDataChanged() {
        guard let snapshot else {
            return
        }
        dataChanged = snapshot != makeSnapshot()
    }

    private func makeSnapshot() -> (PlaylistSettingsItem.StreamListOrder, Bool, Bool, Bool, Bool) {
        (order, pinEnabled, snapshot?.2 ?? false, didUpdateProgramGuide, didUpdatePlaylist)
    }

    isolated deinit {
        logger.info("deinit of \(self)")
    }
}

// MARK: - Playlist order update
extension PlaylistSettingsViewModel {

    func onOrderChange() -> Bool {
        logger.info("Change order", private: identity)
        playlist?.settings?.orderType = order
        updateDataChanged()
        return true
    }
}

// MARK: - Playlist program guide update
extension PlaylistSettingsViewModel {
    func updateProgramGuide() async -> Bool {
        progress = true
        defer {
            progress = false
            updateDataChanged()
        }
        guard let playlist else {
            return false
        }
        logger.info("Update program guide for encrypted=\(playlist.encrypted)", private: identity)
        if playlist.encrypted {
            // Ask a user to enter pin to recover playlist raw data.
            logger.info("Show enter pin to decrypt playlist", private: identity)
            showPinCodeDecryptProgramGuideView = true
            return false
        } else {
            guard let preparedPlaylist = PreparedPlaylist(playlist) else {
                return false
            }
            do {
                // Recover playlist raw data without pin.
                let content = try await playlistAddService.restorePlaylist(preparedPlaylist, pin: nil).content
                didUpdateProgramGuide = try await updateProgramGuide(content)
                return didUpdateProgramGuide
            } catch {
                logger.error(error)
                self.error = .init(error: error)
                return false
            }
        }
    }

    func updateProgramGuideDecrypted() async -> Bool {
        progress = true
        defer {
            progress = false
            playlistDecryptedContent = nil
            updateDataChanged()
        }
        guard let playlist, playlist.encrypted, let content = playlistDecryptedContent else {
            return false
        }
        do {
            didUpdateProgramGuide = try await updateProgramGuide(content)
            return didUpdateProgramGuide
        } catch {
            self.error = .init(error: error)
            logger.error(error)
            return false
        }
    }

    private func updateProgramGuide(_ content: PlaylistItem.Content) async throws -> Bool {
        defer {
            progressText = nil
        }
        logger.info("Updating program guide", private: identity)
        _ = try await playlistService.playlists(for: content, reloadProgramGuide: true, progress: { [weak self] _, step in
            Task { @MainActor in
                switch step {
                case .start, .complete:
                    break
                default:
                    self?.progressText = .init(string: step.title)
                }
            }
        })
        return true
    }
}

// MARK: - Playlist update
extension PlaylistSettingsViewModel {

    func updatePlaylist() async -> Bool {
        progress = true
        defer {
            progress = false
            updateDataChanged()
        }
        guard let playlist else {
            return false
        }
        logger.info("Update playlist for encrypted=\(playlist.encrypted)", private: identity)
        if playlist.encrypted {
            // Ask a user to enter pin to recover playlist raw data.
            logger.info("Show enter pin to decrypt playlist", private: identity)
            showPinCodeDecryptPlaylistView = true
            return false
        } else {
            guard let preparedCachedPlaylist = PreparedPlaylist(playlist) else {
                return false
            }
            do {
                // Recover playlist raw data without pin.
                let content = try await playlistAddService.restorePlaylist(preparedCachedPlaylist, pin: nil).content
                didUpdatePlaylist = try await updatePlaylist(playlist: playlist, content: content)
                return didUpdatePlaylist
            } catch {
                logger.error(error)
                self.error = .init(error: error)
                return false
            }
        }
    }

    func updatePlaylistDecrypted() async -> Bool {
        progress = true
        defer {
            progress = false
            playlistDecryptedContent = nil
            updateDataChanged()
        }
        guard let playlist, let content = playlistDecryptedContent else {
            return false
        }
        do {
            didUpdatePlaylist = try await updatePlaylist(playlist: playlist, content: content)
            return didUpdatePlaylist
        } catch {
            self.error = .init(error: error)
            logger.error(error)
            return false
        }
    }

    private func updatePlaylist(playlist: PlaylistItem, content: PlaylistItem.Content) async throws -> Bool {
        defer {
            progressText = nil
        }
        let originalURLString = String(data: content.url, encoding: .utf8)!
        let isLocalFile = URL(string: originalURLString)?.isFileURL == true
        if isLocalFile && selectedPlaylistFileURL == nil {
            isPlaylistFileImporterPresented = true
            return false
        }
        let updateURLString = isLocalFile
            ? selectedPlaylistFileURL!.absoluteString
            : originalURLString

        logger.info("Updating playlist", private: identity)
        // Read cached playlist.
        let playlistsCache = try await playlistService.playlists(
            for: content, reloadPlaylist: false, progress: { _, _ in }
        )
        guard let mainPlaylist = playlistsCache.first else {
            return false
        }
        // Download an updated playlist from original url. If new playlist version does not have
        // `urlTvg`, `urlImg` and `tvgLogo` then use old cached playlist values.
        var preparedUpdatedPlaylist = try await playlistAddService.preparePlaylist(
            name: content.identity.name,
            urlString: updateURLString,
            pin: nil,
            urlTvg: mainPlaylist.tvgURL ?? mainPlaylist.xTvgURL,
            urlImg: mainPlaylist.imageURL,
            tvgLogo: mainPlaylist.tvgLogo
        ){ [weak self]  _, step in
            switch step {
            case .start, .complete:
                break
            default:
                Task { @MainActor in
                    self?.progressText = .init(string: step.title)
                }
            }
        }
        assert(preparedUpdatedPlaylist.salt == nil)
        assert(!preparedUpdatedPlaylist.encrypted)
        preparedUpdatedPlaylist = PreparedPlaylist(
            name: identity.name,
            // Set date from original playlist as Date is an identity, should not be changed.
            date: identity.date,
            icon: preparedUpdatedPlaylist.icon,
            // A newly selected local file URL is temporary. Keep the original playlist URL
            // as original URL is used for encryption and decryption when encryption enabled,
            // else we won't be able to decrypt the old data.
            url: content.url,
            // Plain text not encrypted data.
            data: preparedUpdatedPlaylist.data,
            salt: preparedUpdatedPlaylist.salt, // nil
            encrypted: preparedUpdatedPlaylist.encrypted // false
        )
        let newContent = try await playlistAddService.restorePlaylist(preparedUpdatedPlaylist, pin: nil).content
        // Update cache with new playlist + update program guide + update images.
        let playlists = try await playlistService.playlists(for: newContent, reloadPlaylist: true, progress: { [weak self] _, step in
            Task { @MainActor in
                switch step {
                case .start, .complete:
                    break
                default:
                    self?.progressText = .init(string: step.title)
                }
            }
        })
        guard !playlists.filter({ !$0.streams.isEmpty }).isEmpty else {
            // In case updated playlist is empty, return back to old one.
            logger.info("Recover playlist back as updated is empty or broken", private: identity)
            _ = try await playlistService.playlists(
                for: content, reloadPlaylist: true, progress: { _, _ in }
            )
            return false
        }
        logger.info("Update playlist data for URL", private: String(data: content.url, encoding: .utf8)!)
        if playlistDecryptedContent == content || playlist.encrypted {
            // Database now has old playlist (playlist.data and playlist.url) that is encrypted.
            // We here have new playlist (data and url) that is not yet encrypted.
            // To encrypt we need ask a user a pin code first, then encrypt data and
            // replace in database old one.
            // We do not replace `url` as we agreed to use old/first one always, only playlist
            // data needs to be updated.
            playlistUpdateContent = .init(
                identity: content.identity,
                url: content.url,
                data: preparedUpdatedPlaylist.data,
                isStoredInMemoryOnly: content.isStoredInMemoryOnly
            )
            showPinCodeReEncryptView = true
            logger.info("New playlist ready to be encrypted, waiting for user pin entry.")
        } else {
            // Database's playlist without encryption, just replace it with new data.
            playlist.data = preparedUpdatedPlaylist.data
        }
        return true
    }
}

// MARK: - Playlist data update
extension PlaylistSettingsViewModel {
    
    func onReEncrypt() async -> Bool {
        defer {
            self.playlistUpdateContent = nil
            self.pin = ""
        }
        guard let playlistUpdateContent, let playlist, !pin.isEmpty else {
            logger.error("Unexpected flow: New playlist content absent.")
            return false
        }
        guard let preparedPlaylist = PreparedPlaylist(playlist) else {
            return false
        }
        do {
            // Check that a user provided correct pin code
            let content = try await playlistAddService.restorePlaylist(preparedPlaylist, pin: pin).content
            logger.info("Pin is correct:", private: pin)
            logger.info("Encrypt new playlist data for url:", private: String(data: content.url, encoding: .utf8)!)
        } catch {
            logger.error("Unexpected flow: pin provided is not correct")
            logger.error(error)
            self.error = .init(error: error)
            return false
        }
        guard let salt = playlist.salt, playlist.encrypted else {
            logger.error("Unexpected flow: Playlist is not encrypted.")
            return false
        }
        do {
            let preparedPlaylist = PreparedPlaylist(
                name: playlistUpdateContent.identity.name,
                date: playlistUpdateContent.identity.date,
                icon: nil,
                url: playlistUpdateContent.url,
                data: playlistUpdateContent.data,
                salt: salt,
                encrypted: false
            )
            let encryptedPlaylist = try await playlistAddService.encryptPlaylist(preparedPlaylist, pin: pin)
            playlist.data = encryptedPlaylist.data
        } catch {
            logger.error(error)
            self.error = .init(error: error)
            return false
        }
        return true
    }
}

// MARK: - Playlist pin update
extension PlaylistSettingsViewModel {

    func onPinChange() {
        guard !pinChangesProgrammatically else {
            pinChangesProgrammatically = false
            return
        }
        progress = true
        defer {
            progress = false
        }
        if pinEnabled {
            logger.info("Show enter pin to encrypt", private: identity)
            showPinCodeEncryptView = true
        } else {
            logger.info("Show enter pin to decrypt", private: identity)
            showPinCodeDecryptView = true
        }
        pinChangesProgrammatically = false
    }

    func onEncrypt() async -> Bool {
        logger.info("Start encryption", private: identity)
        progress = true
        var didEncrypt = false
        defer {
            if !didEncrypt {
                pinChangesProgrammatically = true
                pin = ""
                pinEnabled = false
            }
            progress = false
            updateDataChanged()
        }
        guard !pin.isEmpty else {
            return false
        }
        guard let playlist,
              let date = playlist.date,
              let name = playlist.name,
              let url = playlist.url,
              let data = playlist.data else {
            return false
        }
        do {
            let preparedPlaylist = PreparedPlaylist(
                name: name,
                date: date,
                icon: playlist.icon,
                url: url,
                data: data,
                salt: nil,
                encrypted: false
            )
            let encryptedPlaylist = try await playlistAddService.encryptPlaylist(preparedPlaylist, pin: pin)
            playlist.url = encryptedPlaylist.url
            playlist.data = encryptedPlaylist.data
            playlist.salt = encryptedPlaylist.salt
            playlist.encrypted = encryptedPlaylist.encrypted
            didEncrypt = true
            logger.info("Complete encryption", private: identity)
        } catch {
            logger.error(error)
            return false
        }
        return true
    }

    func onDecrypt() async -> Bool {
        logger.info("Start decryption", private: identity)
        progress = true
        defer {
            progress = false
            playlistDecryptedContent = nil
            updateDataChanged()
        }
        guard let playlistDecryptedContent, let playlist else {
            pinChangesProgrammatically = true
            pinEnabled = true
            return false
        }
        do {
            playlist.data = try await DataCompressor().compress(playlistDecryptedContent.data)
            playlist.url = playlistDecryptedContent.url
            playlist.salt = nil
            playlist.encrypted = false
            logger.info("Complete decryption", private: identity)
        } catch {
            logger.error(error)
            return false
        }
        return true
    }
}
