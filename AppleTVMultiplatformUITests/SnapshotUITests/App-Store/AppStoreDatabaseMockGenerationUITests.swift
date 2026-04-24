import XCTest

@MainActor
final class AppStoreDatabaseMockGenerationUITests: XCTestCase {

    private var env: MockAppEnv!
    private var apiClient: MockApiClient!
    
    override func setUp() async throws {
#if os(macOS)
        XCTFail("iOS Simulator only")
#else
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return XCTFail("iOS Simulator only")
        }
#endif
        try env = .init()
        apiClient = .init(env: env)
    }

    func test() async throws {
        let app = XCUIApplication()
        app.launch()
        
        let testConfig = try await apiClient.config()
        let playlists = testConfig.playlists
        for playlist in playlists {
            try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(0))
            try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
            try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
            try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)

            if playlist.original == "Movies" { // Speed up tests.
                try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
                try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
            }

            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        }
        
        do {
            try await apiClient.copyDatabase()
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}
