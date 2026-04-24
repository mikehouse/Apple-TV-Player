import FactoryKit
import Foundation
import Observation
import SwiftData

@Observable
final class PlaylistViewModel {

    @ObservationIgnored @Injected(\.playlistService) private var playlistService
    @ObservationIgnored @Injected(\.databaseService) private var databaseService
    @ObservationIgnored @Injected(\.logger) private var logger

    let content: PlaylistItem.Content

    private(set) var streams: [[PlaylistParser.Stream]] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var progress: String?
    private let crypto = Crypto()
    // Original iterations very slow when used for sorting.
    private let iterations: UInt32 = 50_000

    init(content: PlaylistItem.Content) {
        self.content = content
    }

    private func loadPlaylist(reloadProgramGuide: Bool) async throws -> [PlaylistParser.Playlist] {
        logger.info("Loading playlist", private: content.id)
        return try await playlistService.playlists(
            for: content,
            reloadProgramGuide: reloadProgramGuide
        ) { [weak self] _, step in
            Task { @MainActor in
                switch step {
                case .start, .complete:
                    break
                default:
                    self?.progress = step.title
                }
            }
        }
    }

    func loadStreams() async {
        isLoading = true
        errorMessage = nil
        progress = streams.isEmpty ? " " : nil
        defer { isLoading = false }

        do {
            var playlists = try await loadPlaylist(reloadProgramGuide: false)
            let programGuides = await playlistService.programGuides(for: content, since: Date())
            if programGuides.isEmpty {
                logger.info("Program guide seems outdated, reload it from scratch ...")
                playlists = try await loadPlaylist(reloadProgramGuide: true)
            }
            let streams = playlists.first?.streams ?? []
            let playlistItem = playlist
            guard let settings = playlistItem?.settings else {
                self.streams = [streams]
                return
            }
            let order = playlistItem?.settings?.orderType ?? .none
            logger.info("Sorting streams with '\(order)'", private: content.id)
            let measure = await measureTime { @MainActor [self] in
                switch order {
                case .none:
                    self.streams = await Task<[[PlaylistParser.Stream]], Never>.detached(priority: .high) {
                        var streamsByGroup: [[PlaylistParser.Stream]] = []
                        let noGroupStreams: [PlaylistParser.Stream] = streams.filter { $0.groupTitle == nil }
                        let haveGroupStreams: [PlaylistParser.Stream] = streams.filter { $0.groupTitle != nil }
                        let groups: [String] = NSOrderedSet(array: haveGroupStreams.compactMap { $0.groupTitle }).array as! [String]
                        for group in groups {
                            streamsByGroup.append(haveGroupStreams.filter { $0.groupTitle == group })
                        }
                        if !noGroupStreams.isEmpty {
                            streamsByGroup.append(noGroupStreams)
                        }
                        return streamsByGroup
                    }.value
                case .ascending:
                    self.streams = await Task<[[PlaylistParser.Stream]], Never>.detached(priority: .high) {
                        [streams.sorted(by: { left, right in
                            return self.title(for: left) < self.title(for: right)
                        })]
                    }.value
                case .descending:
                    self.streams = await Task<[[PlaylistParser.Stream]], Never>.detached(priority: .high) {
                        [streams.sorted(by: { left, right in
                            return self.title(for: left) > self.title(for: right)
                        })]
                    }.value
                case .recentViewed, .mostViewed:
                    let expectOrder: [String]
                    if order == .mostViewed {
                        expectOrder = await Task<[String], Never>.detached(priority: .high) { [views=settings.views, encrypted=settings.encrypted] in
                            views.sorted(by: { $0.value > $1.value }).compactMap({ encrypted[$0.key] }).map { self.decode(title: $0) }
                        }.value
                    } else if order == .recentViewed {
                        expectOrder = await Task<[String], Never>.detached(priority: .high) { [recent=settings.recent, encrypted=settings.encrypted] in
                            recent.sorted(by: { $0.value > $1.value }).compactMap({ encrypted[$0.key] }).map { self.decode(title: $0) }
                        }.value
                    } else {
                        fatalError()
                    }
                    var actualOrder: [PlaylistParser.Stream] = []
                    actualOrder.reserveCapacity(streams.count)
                    var indexes: Set<Int> = []
                    for expect in expectOrder {
                        guard let index = streams.firstIndex(where: { expect == title(for: $0) }) else { continue }
                        actualOrder.append(streams[index])
                        indexes.insert(index)
                    }
                    Set((0..<streams.count)).subtracting(indexes).sorted().forEach { index in
                        actualOrder.append(streams[index])
                    }
                    self.streams = [actualOrder]
                }
            }
            logger.info("Streams sorting completed in \(measure.milliseconds) milliseconds")
        } catch {
            logger.error(error, private: content.id)
            streams = []
            errorMessage = errorMessage(for: error)
        }
    }

    nonisolated func title(for stream: PlaylistParser.Stream) -> String {
        let tvgName = stream.tvgName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (tvgName?.isEmpty == false ? tvgName : nil) ?? stream.title
    }

    func subtitle(for stream: PlaylistParser.Stream) async -> String? {
        guard let guide = await playlistService.programGuide(for: content, stream: stream) else {
            return nil
        }
        let now = Date()
        return guide.programs.first(where: { $0.start <= now && now < $0.stop })?.title
    }

    func selectedStream(_ stream: PlaylistParser.Stream) {
        if let playlist, let settings = playlist.settings {
            let (hmac, encrypted) = encode(title: title(for: stream))
            settings.views[hmac, default: 0] += 1
            settings.recent[hmac] = Date()
            settings.encrypted[hmac] = encrypted
        }
    }

    nonisolated private func salt() -> Data {
        var salt = Data(content.url.dropLast(content.url.count - Crypto.keyLength))
        while salt.count < Crypto.keyLength {
            salt.append(0x0)
        }
        return salt
    }

    func encode(title: String) -> (hmac: String, encrypted: String) {
        // Use `content.url` as pin and salt because when encrypted it is hidden under user passcode.
        // It is enough to secure this data that does not disclose a way to brute-force the passcode.
        let pin = String(data:  content.url, encoding: .utf8)!
        let salt = salt()
        let encrypted = (try? crypto.encrypt(title, pin: pin, salt: salt, iterations: iterations))?.base64EncodedString() ?? title
        let hmac = (try? crypto.hmac(title, pin: pin, salt: salt, iterations: iterations)) ?? title
        return (hmac, encrypted)
    }

    nonisolated func decode(title: String) -> String {
        guard let data = Data(base64Encoded: title) else {
            return title
        }
        let pin = String(data: content.url, encoding: .utf8)!
        let salt = salt()
        return (try? crypto.decrypt(data, pin: pin, salt: salt, iterations: iterations)) ?? title
    }

    private var playlist: PlaylistItem? {
        let fetch = FetchDescriptor<PlaylistItem>()
        return try? databaseService.mainContext.fetch(fetch)
            .first(where: { $0.identity == content.identity })
    }

    isolated deinit {
        logger.info("deinit of \(self)")
    }
}

private extension PlaylistViewModel {

    func errorMessage(for error: Swift.Error) -> String? {
        if (error as NSError).code == NSURLErrorCancelled {
            return nil
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }

        return "\(error)"
    }
}
