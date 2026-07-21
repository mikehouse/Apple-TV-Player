import SnapshotTesting
import XCTest
import Testing

@MainActor
final class RegularSnapshotUITests_PlaylistUpdate: XCTestCase {

    private var env: MockAppEnv!
    private var apiClient: MockApiClient!
    private var snapshotUtils: SnapshotUtils!
    
    override func setUp() async throws {
        try env = .init()
        apiClient = .init(env: env)
        snapshotUtils = .init(env: env, apiClient: apiClient, name: "Regular")
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
#endif
    }

    func test() async throws {
        let testConfig = try await apiClient.config()
        let app = XCUIApplication()
#if !os(tvOS)
        // iOS, macOS it is easy to type the data into create playlist controls,
        // that is why we create a playlist with data in the test from scratch in in memory database.
        app.launchArguments.append("--in-memory-database-only")
#endif
#if os(macOS)
        app.launchArguments.append("--window-fixed-size")
#endif
#if os(tvOS)
        let databaseConfig = try await apiClient.databaseConfig()
        // on tvOS it is hard to type long text with tvOS keyboard.
        // Use prefilled database.
        app.launchArguments.append(
            "DATABASE_PATH=\(databaseConfig.path)"
        )
#endif
        app.launch()
        app.activate()
        try await Task.sleep(for: .seconds(1))
        
        let playlists = testConfig.playlists
        // "Movies" playlist has data to test all app flows.
        // Is reversed because UI sorts by date added.
        guard let testPlaylist = playlists.first(where: { $0.original == "Movies" }) else {
            XCTFail("Movies playlist not found in test configuration")
            return
        }
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            try await iPhone(app: app, playlist: testPlaylist)
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            try await iPad(app: app, playlist: testPlaylist)
        } else {
            XCTFail("Unsupported device = \(UIDevice.current.userInterfaceIdiom.rawValue)")
        }
#elseif os(tvOS)
        try await tvOS(app: app, playlist: testPlaylist)
#else
        try await macOS(app: app, playlist: testPlaylist)
#endif
    }
    
#if os(iOS)
    private func iPad(app: XCUIApplication, playlist: Playlist) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .pad)
        continueAfterFailure = true
        if #available(iOS 26.0, *) {
        } else {
            try await app.buttons["ToggleSidebar"].firstMatch.makeTap(wait: .seconds(1))
        }
        try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(1))
        try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
        try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
        try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
        try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
        try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        try await app.collectionViews["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist"), app: app, localized: false, precision: 0.999)
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        
        try await apiClient.playlistReset(playlist)
        try await apiClient.playlistChange(playlist)
        
        try await app.buttons["update-playlist-btn"].firstMatch.makeTap(wait: .seconds(2))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Westerns")
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist-update"), app: app, localized: false, precision: 0.999)
        
        try await apiClient.playlistReset(playlist)
    }
    
    private func iPhone(app: XCUIApplication, playlist: Playlist) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .phone)
        continueAfterFailure = true
        try await app.buttons["add"].firstMatch.makeTap()
        try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
        try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
        try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
        try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
        try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        try await app.cells.firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist"), app: app, localized: false)
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        
        try await apiClient.playlistReset(playlist)
        try await apiClient.playlistChange(playlist)
        
        try await app.buttons["update-playlist-btn"].firstMatch.makeTap(wait: .seconds(2))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Westerns")
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist-update"), app: app, localized: false, precision: 0.9992)
        
        try await apiClient.playlistReset(playlist)
    }
#endif
#if os(tvOS)
    private func tvOS(app: XCUIApplication, playlist: Playlist) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .tv)
        continueAfterFailure = true
        func openSettings() async throws {
            XCUIRemote.shared.press(.select, forDuration: 1)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.select)
            try await Task.sleep(for: .seconds(1))
        }
         try await Task.sleep(for: .seconds(1))
         XCUIRemote.shared.press(.select)
         try await Task.sleep(for: .seconds(2))
         XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.hasFocus, true)
         XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.buttons.firstMatch.label, "Comedy, Vacation")
         XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
         XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist"), app: app, localized: false, precision: 0.999)
        
        XCUIRemote.shared.press(.menu)
         try await Task.sleep(for: .seconds(1))

        try await apiClient.playlistReset(playlist)
        try await apiClient.playlistChange(playlist)
        
        try await openSettings()
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(2))
        XCUIRemote.shared.press(.menu)
        try await Task.sleep(for: .seconds(2))

        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.hasFocus, true)
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.buttons.firstMatch.label, "Westerns")
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Westerns")
        XCTAssertEqual(app.tables.firstMatch.cells.element(boundBy: 1).label, "Sitcoms")
        
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist-update"), app: app, localized: false, precision: 0.999)
        
        try await apiClient.playlistReset(playlist)
    }
#endif
#if os(macOS)
    private func macOS(app: XCUIApplication, playlist: Playlist) async throws {
        continueAfterFailure = true
        try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
        try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
        try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
        try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
        try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
        try await app.sheets.firstMatch.buttons["add"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.staticTexts["select-playlist"].firstMatch.value as? String, "Select a playlist")
        try await app.outlines["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Comedy")
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 1).value as? String, "Vacation")
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist"), app: app, localized: false)
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        
        try await apiClient.playlistReset(playlist)
        try await apiClient.playlistChange(playlist)
        
        try await app.buttons["update-playlist-btn"].firstMatch.makeTap(wait: .seconds(2))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Westerns")
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist-update"), app: app, localized: false)
        
        try await apiClient.playlistReset(playlist)
    }
#endif
}
