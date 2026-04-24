import SnapshotTesting
import XCTest
import Testing

@MainActor
final class AppStoreSnapshotUITests: XCTestCase {

    private var env: MockAppEnv!
    private var apiClient: MockApiClient!
    private var snapshotUtils: SnapshotUtils!
    
    override func setUp() async throws {
        try env = .init()
        apiClient = .init(env: env)
        snapshotUtils = .init(env: env, apiClient: apiClient, name: "App-Store-Snapshot")
        continueAfterFailure = false
#if os(iOS)
        try await apiClient.setSimAppearance(dark: false)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
#endif
    }
    
    override func tearDown() async throws {
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .portrait
        }
        try await apiClient.setSimAppearance(dark: false)
#endif
    }

    func test() async throws {
        let testConfig = try await apiClient.config()
        let databaseConfig = try await apiClient.databaseConfig()
        let app = XCUIApplication()
#if os(macOS)
        app.launchArguments.append("--window-fixed-size")
#endif
        app.launchArguments.append(
            "DATABASE_PATH=\(databaseConfig.path)"
        )
        app.launch()
        app.activate()
        try await Task.sleep(for: .seconds(1))
        
        let playlists = testConfig.playlists
         // "Movies" playlist has data to test all app flows.
         // Is reversed because UI sorts by date added.
        guard let testPlaylistId = Array(playlists.reversed()).firstIndex(where: { $0.original == "Movies" }) else {
            XCTFail("Movies playlist not found in test configuration")
            return
        }
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            try await iPhone(app: app, playlistId: testPlaylistId)
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            try await iPad(app: app, playlistId: testPlaylistId)
        } else {
            XCTFail("Unsupported device = \(UIDevice.current.userInterfaceIdiom.rawValue)")
        }
#elseif os(tvOS)
        try await tv(app: app, playlistId: testPlaylistId, playlistCount: playlists.count)
#else
        try await macOS(app: app, playlistId: testPlaylistId)
#endif
    }
    
#if os(tvOS)
    private func tv(app: XCUIApplication, playlistId: Int, playlistCount: Int) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .tv)
        continueAfterFailure = true
        try await Task.sleep(for: .seconds(1))
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlists"), app: app, localized: true, precision: 0.9995)
        for _ in 0..<playlistCount {
            XCUIRemote.shared.press(.down)
        }
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(2))
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlist-add"), app: app, localized: true, precision: 0.996)
        XCUIRemote.shared.press(.menu)
        try await Task.sleep(for: .seconds(1))
        try await app.cells.element(boundBy: playlistId).makeTap()
        try await app.cells.element(boundBy: 0).makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "stream"), app: app, localized: true, precision: 0.998)
        XCUIRemote.shared.press(.menu)
        try await Task.sleep(for: .seconds(1))
        XCUIRemote.shared.press(.select, forDuration: 1)
        XCUIRemote.shared.press(.down)
        try await Task.sleep(for: .seconds(3))
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlist-settings-menu"), app: app, localized: true, precision: 0.98)
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(3))
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlist-settings"), app: app, localized: true, precision: 0.95)
        XCUIRemote.shared.press(.menu)
    }
#endif
#if os(iOS)
    private func iPad(app: XCUIApplication, playlistId: Int) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .pad)
        continueAfterFailure = true
        try await app.buttons["add"].firstMatch.makeTap()
        // If precision < 0.9996 it does not react on different time in status bar.
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlist-add"), app: app, localized: true, precision: 0.996)
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(1))
        try await app.cells.element(boundBy: playlistId).makeTap(wait: .seconds(1))
        try await app.cells.element(boundBy: 0).makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "stream"), app: app, localized: true, precision: 0.9996)
        try await apiClient.setSimAppearance(dark: true)
        try await Task.sleep(for: .seconds(2))
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: true, context: "playlists"), app: app, localized: true, precision: 0.9996)
        try await app.cells.element(boundBy: playlistId).makeTap(wait: .seconds(1))
        try await app.buttons["settings"].firstMatch.makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: true, context: "playlist-settings"), app: app, localized: true, precision: 0.9996)
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(0))
    }
    
    private func iPhone(app: XCUIApplication, playlistId: Int) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .phone)
        continueAfterFailure = true
        // If precision < 0.9994 it does not react on different time in status bar.
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlists"), app: app, localized: true, precision: 0.9993)
        try await app.buttons["add"].firstMatch.makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlist-add"), app: app, localized: true, precision: 0.9994)
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(1))
        try await app.cells.element(boundBy: playlistId).makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlist"), app: app, localized: true, precision: 0.9994)
        try await app.cells.element(boundBy: 0).makeTap()
        // Set precision 0.995 (< 0.9994) because Apple Video Player has baggy background.
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "stream"), app: app, localized: true, precision: 0.995)
        try await apiClient.setSimAppearance(dark: true)
        try await app.buttons["BackButton"].firstMatch.makeTap(wait: .seconds(1))
        try await app.buttons["BackButton"].firstMatch.makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: true, context: "playlists"), app: app, localized: true, precision: 0.9993)
        try await app.cells.element(boundBy: playlistId).makeTap(wait: .seconds(2))
        try await app.buttons["settings"].firstMatch.makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(dark: true, context: "playlist-settings"), app: app, localized: true, precision: 0.9994)
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(0))
    }
#endif
#if os(macOS)
    private func macOS(app: XCUIApplication, playlistId: Int) async throws {
        continueAfterFailure = true
        try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(2))
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlist-add"), app: app, localized: true, precision: 0.94)
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(0))
        try await app.outlines["sidebar"].cells.element(boundBy: playlistId).makeTap(wait: .seconds(0))
        try await app.outlines["content"].cells.element(boundBy: 1).makeTap(wait: .seconds(3))
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "stream"), app: app, localized: true, precision: 0.999)
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(2))
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(dark: false, context: "playlist-settings"), app: app, localized: true, precision: 0.94)
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(0))
    }
#endif
}
