import FactoryKit
import Foundation

protocol PlaylistAddServiceInterface: AnyObject, Sendable {
    typealias ProgressHandler = @Sendable ([PlaylistAddService.Progress], PlaylistAddService.Progress) -> Void
    func preparePlaylist(name: String?, urlString: String, pin: String?, urlTvg: String?, urlImg: String?, tvgLogo: String?, progress: ProgressHandler) async throws -> PreparedPlaylist
    func encryptPlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String) async throws -> PreparedPlaylist
    func restorePlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String?) async throws -> RestoredPlaylist
}

struct PreparedPlaylist: Sendable, Equatable {
    let name: String
    let date: Date
    let icon: String?
    let url: Data
    let data: Data
    let salt: Data?
    let encrypted: Bool
}

struct RestoredPlaylist: Sendable, Equatable {
    let name: String
    let date: Date
    let icon: String?
    let url: Data
    let data: Data
    let isStoredInMemoryOnly: Bool
}

extension RestoredPlaylist {

    var content: PlaylistItem.Content {
        PlaylistItem.Content(
            identity: .init(name: name, date: date),
            url: url,
            data: data,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
    }
}

extension PreparedPlaylist {

    init?(_ playlistItem: PlaylistItem) {
        guard
            let name = playlistItem.name,
            let date = playlistItem.date,
            let url = playlistItem.url,
            let data = playlistItem.data
        else {
            return nil
        }

        self.init(
            name: name,
            date: date,
            icon: playlistItem.icon,
            url: url,
            data: data,
            salt: playlistItem.salt,
            encrypted: playlistItem.encrypted
        )
    }
}

actor PlaylistAddService: PlaylistAddServiceInterface {

    enum Progress: String, Hashable, CaseIterable, Sendable {
        case start
        case downloading
        case parsing
        case compressing
        case encrypting
        case complete
        
        var title: String {
            switch self {
            case .start:
                return String(localized: "Starting")
            case .downloading:
                return String(localized: "Download Playlist")
            case .parsing:
                return String(localized: "Reading Playlist")
            case .compressing:
                return String(localized: "Compressing Playlist")
            case .encrypting:
                return String(localized: "Encrypting Playlist")
            case .complete:
                return String(localized: "Complete")
            }
        }
    }

    enum Error: Swift.Error, LocalizedError, Equatable {
        case invalidURL
        case invalidPlaylist
        case downloadFailed(Int)
        case pinRequired
        case invalidPin
        case invalidPreparedPlaylist

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Enter a valid playlist URL."
            case .invalidPlaylist:
                return "The downloaded file is not a valid playlist."
            case .downloadFailed(let statusCode):
                return "Failed to download playlist (HTTP \(statusCode))."
            case .pinRequired:
                return "Enter the playlist PIN."
            case .invalidPin:
                return "Enter the correct playlist PIN."
            case .invalidPreparedPlaylist:
                return "The stored playlist data is invalid."
            }
        }
    }

    private struct ResolvedSource {
        let url: URL
        let data: Data
    }

    private struct RestoredSource {
        let url: Data
        let data: Data
    }

    nonisolated private static let attributePattern = #"([A-Za-z0-9-]+)=("([^"]*)"|([^\s,]+))"#

    private let compressor = DataCompressor()
    private let crypto = Crypto()
    @ObservationIgnored @Injected(\.logger) private var logger

    func preparePlaylist(
        name: String?,
        urlString: String,
        pin: String?,
        urlTvg: String?,
        urlImg: String?,
        tvgLogo: String?,
        progress: ProgressHandler
    ) async throws -> PreparedPlaylist {
        let progressList = Progress.allCases.filter {
            if pin == nil {
                return true
            }
            return $0 != .encrypting
        }
        defer {
            progress(progressList, .complete)
        }
        progress(progressList, .start)
        progress(progressList, .downloading)
        let resolvedSource = try await resolveSource(from: urlString)
        let playlistData = try injectingPlaylistHeaderAttributes(
            into: resolvedSource.data,
            urlTvg: urlTvg,
            urlImg: urlImg,
            tvgLogo: tvgLogo
        )
        progress(progressList, .parsing)
        let playlists = try await parsePlaylists(from: playlistData)
        let playlistName = resolvedName(from: name, sourceURL: resolvedSource.url)
        let playlistIcon = resolvedIcon(from: playlists)
        progress(progressList, .compressing)
        let normalizedURLData = Data(resolvedSource.url.absoluteString.utf8)
        let compressedData = try await compressor.compress(playlistData)

        guard let normalizedPin = normalized(pin) else {
            return PreparedPlaylist(
                name: playlistName,
                date: Date(),
                icon: playlistIcon,
                url: normalizedURLData,
                data: compressedData,
                salt: nil,
                encrypted: false
            )
        }

        progress(progressList, .encrypting)
        let salt = Crypto.generateSalt()
        let encryptedURLData = try crypto.encrypt(normalizedURLData, pin: normalizedPin, salt: salt)
        let encryptedPlaylistData = try crypto.encrypt(compressedData, pin: normalizedPin, salt: salt)

        return PreparedPlaylist(
            name: playlistName,
            date: Date(),
            icon: playlistIcon,
            url: encryptedURLData,
            data: encryptedPlaylistData,
            salt: salt,
            encrypted: true
        )
    }

    func encryptPlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String) async throws -> PreparedPlaylist {
        assert(preparedPlaylist.encrypted == false)
        let salt = Crypto.generateSalt()
        let encryptedURLData = try crypto.encrypt(preparedPlaylist.url, pin: pin, salt: salt)
        let encryptedPlaylistData = try crypto.encrypt(preparedPlaylist.data, pin: pin, salt: salt)

        return PreparedPlaylist(
            name: preparedPlaylist.name,
            date: preparedPlaylist.date,
            icon: preparedPlaylist.icon,
            url: encryptedURLData,
            data: encryptedPlaylistData,
            salt: salt,
            encrypted: true
        )
    }

    func restorePlaylist(_ preparedPlaylist: PreparedPlaylist, pin: String?) async throws -> RestoredPlaylist {
        let restoredSource = try await restoredSource(from: preparedPlaylist, pin: pin)

        return RestoredPlaylist(
            name: preparedPlaylist.name,
            date: preparedPlaylist.date,
            icon: preparedPlaylist.icon,
            url: restoredSource.url,
            data: restoredSource.data,
            isStoredInMemoryOnly: preparedPlaylist.encrypted
        )
    }
}

private extension PlaylistAddService {

    private func resolveSource(from source: String) async throws -> ResolvedSource {
        logger.info("Download playlist data", private: source)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            throw Error.invalidURL
        }

        if let url = URL(string: trimmedSource), url.scheme != nil {
            if url.isFileURL {
                return ResolvedSource(url: url, data: try Data(contentsOf: url))
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               !(200 ... 299).contains(httpResponse.statusCode) {
                throw Error.downloadFailed(httpResponse.statusCode)
            }

            return ResolvedSource(url: url, data: data)
        }

        let fileURL = URL(fileURLWithPath: (trimmedSource as NSString).expandingTildeInPath)
        return ResolvedSource(url: fileURL, data: try Data(contentsOf: fileURL))
    }

    private func parsePlaylists(from data: Data) async throws -> [PlaylistParser.Playlist] {
        do {
            let playlists = try await PlaylistParser(data: data).parse().filter { !$0.streams.isEmpty }
            guard !playlists.isEmpty else {
                throw Error.invalidPlaylist
            }
            return playlists
        } catch let error as Error {
            throw error
        } catch {
            throw Error.invalidPlaylist
        }
    }

    private func injectingPlaylistHeaderAttributes(
        into data: Data,
        urlTvg: String?,
        urlImg: String?,
        tvgLogo: String?
    ) throws -> Data {
        let normalizedURLTvg = normalized(urlTvg)
        let normalizedURLImg = normalized(urlImg)
        let normalizedTvgLogo = normalized(tvgLogo)

        guard normalizedURLTvg != nil || normalizedURLImg != nil || normalizedTvgLogo != nil else {
            return data
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw Error.invalidPlaylist
        }

        let firstLine: Substring
        let remainingContent: Substring

        if let newlineRange = content.rangeOfCharacter(from: .newlines) {
            firstLine = content[..<newlineRange.lowerBound]
            remainingContent = content[newlineRange.lowerBound...]
        } else {
            firstLine = content[content.startIndex..<content.endIndex]
            remainingContent = Substring()
        }

        guard let updatedLine = updatedPlaylistHeaderLine(
            from: String(firstLine),
            urlTvg: normalizedURLTvg,
            urlImg: normalizedURLImg,
            tvgLogo: normalizedTvgLogo
        ) else {
            return data
        }

        return Data((updatedLine + remainingContent).utf8)
    }

    private func updatedPlaylistHeaderLine(
        from line: String,
        urlTvg: String?,
        urlImg: String?,
        tvgLogo: String?
    ) -> String? {
        guard line.hasPrefix("#EXTM3U") else {
            return nil
        }

        var updatedLine = line

        if let urlTvg {
            logger.info("Set custom url-tvg", private: urlTvg)
            updatedLine += " url-tvg=\"\(urlTvg)\""
        }

        if let urlImg {
            logger.info("Set custom url-img", private: urlImg)
            updatedLine += " url-img=\"\(urlImg)\""
        }

        if let tvgLogo {
            logger.info("Set custom tvg-logo", private: tvgLogo)
            updatedLine += " tvg-logo=\"\(tvgLogo)\""
        }

        return updatedLine
    }

    private func parsedAttributes(in line: String) -> [String: String] {
        let attributeRegex = try! NSRegularExpression(pattern: Self.attributePattern)
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        var attributes: [String: String] = [:]

        for match in attributeRegex.matches(in: line, range: nsRange) {
            guard let keyRange = Range(match.range(at: 1), in: line) else {
                continue
            }

            let key = String(line[keyRange])
            let valueRange = Range(match.range(at: 3), in: line)
                ?? Range(match.range(at: 4), in: line)

            guard let valueRange else {
                continue
            }

            attributes[key] = String(line[valueRange])
        }

        return attributes
    }

    private func resolvedName(from name: String?, sourceURL: URL) -> String {
        if let normalizedName = normalized(name) {
            return normalizedName
        }

        let lastPathComponent = sourceURL.lastPathComponent.removingPercentEncoding ?? sourceURL.lastPathComponent
        if !lastPathComponent.isEmpty {
            return lastPathComponent
        }

        if let host = sourceURL.host, !host.isEmpty {
            return host
        }

        return sourceURL.absoluteString
    }

    private func resolvedIcon(from playlists: [PlaylistParser.Playlist]) -> String? {
        for playlist in playlists {
            if let tvgLogo = normalized(playlist.tvgLogo) {
                return tvgLogo
            }
        }

        return nil
    }

    private func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }

    private func restoredSource(from preparedPlaylist: PreparedPlaylist, pin: String?) async throws -> RestoredSource {
        let restoredURLData: Data
        let compressedData: Data

        if preparedPlaylist.encrypted {
            guard let normalizedPin = normalized(pin) else {
                throw Error.pinRequired
            }

            guard let salt = preparedPlaylist.salt else {
                throw Error.invalidPreparedPlaylist
            }

            do {
                restoredURLData = try crypto.decrypt(preparedPlaylist.url, pin: normalizedPin, salt: salt)
                compressedData = try crypto.decrypt(preparedPlaylist.data, pin: normalizedPin, salt: salt)
            } catch {
                throw Error.invalidPin
            }
        } else {
            restoredURLData = preparedPlaylist.url
            compressedData = preparedPlaylist.data
        }

        do {
            return RestoredSource(
                url: restoredURLData,
                data: try await compressor.decompress(compressedData)
            )
        } catch {
            throw Error.invalidPreparedPlaylist
        }
    }
}

extension FactoryKit.Container {

    @MainActor
    var playlistAddService: Factory<PlaylistAddServiceInterface> {
        self { PlaylistAddService() }.singleton
    }
}
