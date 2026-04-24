
import Foundation
import XCTest

struct Config: Codable {
    let playlists: [Playlist]
}

struct Playlist: Codable {
    let original: String
    let name: String
    let lang: String
    let url: String
    let tvgLogo: String
    let urlTvg: String
    let urlImg: String

    enum CodingKeys: String, CodingKey {
        case original
        case name
        case lang
        case url
        case tvgLogo = "tvg-logo"
        case urlTvg = "url-tvg"
        case urlImg = "url-img"
    }
}

struct DatabaseConfig: Codable {
    let path: String
}

actor MockApiClient {
    
    let env: MockAppEnv
    let session = URLSession(configuration: .ephemeral)

    init(env: MockAppEnv) {
        self.env = env
    }

    func config() async throws -> Config {
        let url = URL(string: "http://localhost:\(env.port)/config?lang=\(env.lang)")!
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Config.self, from: data)
    }

    func databaseConfig() async throws -> DatabaseConfig {
        let url = URL(string: "http://localhost:\(env.port)/database-config?lang=\(env.lang)")!
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(DatabaseConfig.self, from: data)
    }

    func setSimAppearance(dark: Bool) async throws {
        let url = URL(string: "http://localhost:\(env.port)/set-appearance?mode=\(dark ? "dark" : "light")&uuid=\(env.simId)")!
        let _ = try await session.data(from: url)
    }

    func copyDatabase() async throws {
        let url = URL(string: "http://localhost:\(env.port)/copy-database?lang=\(env.lang)&uuid=\(env.simId)")!
        let _ = try await session.data(from: url)
    }

#if os(macOS)
    func copySnapshot(from: String, to dir: String) async throws  {
        let url = URL(string: "http://localhost:\(env.port)/copy-snapshot?snapshot=\(from)&destination=\(dir)")!
        let (_, response) = try await session.data(from: url)
        if let response = response as? HTTPURLResponse, response.statusCode != 200 {
            throw NSError(domain: "localhost.domain", code: response.statusCode, userInfo: [
                NSLocalizedDescriptionKey: response.description
            ])
        }
    }
#endif
}
