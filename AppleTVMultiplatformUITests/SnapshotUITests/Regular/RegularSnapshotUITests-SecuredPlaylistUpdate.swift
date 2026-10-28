import SnapshotTesting
import XCTest
import Testing

@MainActor
final class RegularSnapshotUITests_SecuredPlaylistUpdate: XCTestCase {

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
        app.launchArguments.append("--in-memory-database-only")
#if os(macOS)
        app.launchArguments.append("--window-fixed-size")
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
        guard let tempPlaylist = playlists.first(where: { $0.original != "Movies" }) else {
            XCTFail("Movies playlist not found in test configuration")
            return
        }
#if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            try await iPhone(app: app, playlist: testPlaylist, tempPlaylist: tempPlaylist)
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            try await iPad(app: app, playlist: testPlaylist, tempPlaylist: tempPlaylist)
        } else {
            XCTFail("Unsupported device = \(UIDevice.current.userInterfaceIdiom.rawValue)")
        }
#elseif os(tvOS)
        // On TVOS is hard to type long texts (playlists content), skip the device type.
        XCTFail("Unsupported device = \(UIDevice.current.userInterfaceIdiom.rawValue)")
#else
        try await macOS(app: app, playlist: testPlaylist, tempPlaylist: tempPlaylist)
#endif
    }
    
#if os(iOS)
    private func iPad(app: XCUIApplication, playlist: Playlist, tempPlaylist: Playlist) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .pad)
        continueAfterFailure = true
        if #available(iOS 26.0, *) {
        } else {
            try await app.buttons["ToggleSidebar"].firstMatch.makeTap(wait: .seconds(1))
        }
        let passcode = "1234"
        for playlist in [tempPlaylist, playlist] {
            try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(1))
            try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
            if playlist.original == "Movies" {
                try await app.textFields["passcode"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
            }
            try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
            try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
            try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
            try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        }
        try await app.collectionViews["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        
        try await apiClient.playlistReset(playlist)
        try await apiClient.playlistChange(playlist)
        
        try await app.buttons["update-playlist-btn"].firstMatch.makeTap(wait: .seconds(2))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(1)).typeText(passcode)
        if #available(iOS 26.0, *) {
            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        } else {
            try await app.navigationBars.element(boundBy: 4).buttons["confirm"].firstMatch.makeTap(wait: .seconds(2))
        }
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(1)).typeText(passcode)
        if #available(iOS 26.0, *) {
            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        } else {
            try await app.navigationBars.element(boundBy: 4).buttons["confirm"].firstMatch.makeTap(wait: .seconds(2))
        }
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Westerns")
        
        try await app.collectionViews["sidebar"].firstMatch.cells.element(boundBy: 1).makeTap(wait: .seconds(1))
        try await app.collectionViews["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(1))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Westerns")
        
        try await apiClient.playlistReset(playlist)
    }
    
    private func iPhone(app: XCUIApplication, playlist: Playlist, tempPlaylist: Playlist) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .phone)
        continueAfterFailure = true
        let passcode = "1234"
        for playlist in [tempPlaylist, playlist] {
            try await app.buttons["add"].firstMatch.makeTap()
            try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
            try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
            if playlist.original == "Movies" {
                try await app.textFields["passcode"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
            }
            try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
            try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
            try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        }
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Movies")
        try await app.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        
        try await apiClient.playlistReset(playlist)
        try await apiClient.playlistChange(playlist)
        
        try await app.buttons["update-playlist-btn"].firstMatch.makeTap(wait: .seconds(2))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(1)).typeText(String(passcode))
        try await app.buttons["confirm"].makeTap(wait: .seconds(1))
        
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(1)).typeText(String(passcode))
        try await app.buttons["confirm"].makeTap(wait: .seconds(1))
        try await app.buttons["confirm"].makeTap(wait: .seconds(1))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Westerns")
        
        if #available(iOS 26.0, *) {
            try await app.buttons["BackButton"].firstMatch.makeTap(wait: .seconds(0))
        } else {
            try await app.navigationBars.firstMatch.buttons.firstMatch.makeTap(wait: .seconds(1))
        }
        
        try await app.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Westerns")
        
        try await apiClient.playlistReset(playlist)
    }
#endif
#if os(macOS)
    private func macOS(app: XCUIApplication, playlist: Playlist, tempPlaylist: Playlist) async throws {
        continueAfterFailure = true
        let passcode = "1234"
        for playlist in [tempPlaylist, playlist] {
            try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(0))
            try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
            try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
            if playlist.original == "Movies" {
                try await app.textFields["passcode"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
            }
            try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
            try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
            try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
            try await app.sheets.firstMatch.buttons["add"].firstMatch.makeTap(wait: .seconds(1))
        }
        XCTAssertEqual(app.staticTexts["select-playlist"].firstMatch.value as? String, "Select a playlist")
        try await app.outlines["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Comedy")
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 1).value as? String, "Vacation")
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        
        try await apiClient.playlistReset(playlist)
        try await apiClient.playlistChange(playlist)
        
        try await app.buttons["update-playlist-btn"].firstMatch.makeTap(wait: .seconds(1))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(1)).typeText(String(passcode))
        try await app.sheets.element(boundBy: 1).buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(1)).typeText(String(passcode))
        try await app.sheets.element(boundBy: 1).buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Westerns")
        
        try await app.outlines["sidebar"].firstMatch.cells.element(boundBy: 1).makeTap(wait: .seconds(1))
        try await app.outlines["sidebar"].firstMatch.cells.element(boundBy: 0).makeTap(wait: .seconds(1))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Westerns")
        
        try await apiClient.playlistReset(playlist)
    }
#endif
}
