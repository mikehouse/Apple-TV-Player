import SnapshotTesting
import XCTest
import Testing

@MainActor
final class RegularSnapshotUITests_Passcode: XCTestCase {

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
        app.launchArguments.append("--in-memory-database-only")
#endif
#if os(macOS)
        app.launchArguments.append("--window-fixed-size")
#endif
#if os(tvOS)
        let databaseConfig = try await apiClient.databaseConfig()
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
        guard let testPlaylistId = playlists.firstIndex(where: { $0.original == "Movies" }) else {
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
        try await tvOS(app: app, playlistCount: playlists.count)
#else
        try await macOS(app: app, playlistId: testPlaylistId)
#endif
    }
    
#if os(iOS)
    private func iPad(app: XCUIApplication, playlistId: Int) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .pad)
        continueAfterFailure = true
        if #available(iOS 26.0, *) {
        } else {
            try await app.buttons["ToggleSidebar"].firstMatch.makeTap(wait: .seconds(1))
        }
        let playlists = try await apiClient.config().playlists
        let playlist = playlists[playlistId]
        do {
            if let somePlaylist = playlists.first(where: { $0.url != playlist.url }) {
                try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(1))
                try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.name)
                try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.url)
                try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.tvgLogo)
                try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
            }
        }
        let passcode = "123456"
        try await app.buttons["add"].firstMatch.makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "add-playlist-blank"), app: app, localized: false)
        try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
        try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
        try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
        try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
        try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
        try await app.textFields["passcode"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "add-playlist-filled"), app: app, localized: false, precision: 0.99)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlists"), app: app, localized: false)
        // Last added always first in a list.
        XCTAssertEqual(app.collectionViews["sidebar"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Movies")
        try await app.collectionViews["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.staticTexts["select-playlist"].firstMatch.label, "Select a playlist")
        XCTAssertEqual(app.collectionViews["sidebar"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Movies")
        try await app.collectionViews["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode.dropLast(2)))
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "passcode-input"), app: app, localized: false)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.alerts.firstMatch.staticTexts.element(boundBy: 1).label, "Enter the correct playlist PIN.")
        try await app.buttons["ok"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode.dropFirst(4)))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist"), app: app, localized: false)
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.buttons["passcode-picker"].firstMatch.label, "Enabled")
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "settings"), app: app, localized: false)
        try await app.buttons["passcode-picker"].firstMatch.makeTap(wait: .seconds(0))
        try await app.buttons["passcode-disable"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        if #available(iOS 26.0, *) {
            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        } else {
            try await app.navigationBars.element(boundBy: 4).buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        }
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        try await app.collectionViews["sidebar"].firstMatch.cells.element(boundBy: 1).makeTap(wait: .seconds(0))
        try await app.collectionViews["sidebar"].firstMatch.cells.element(boundBy: 0).makeTap(wait: .seconds(0))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.buttons["passcode-picker"].firstMatch.label, "Disabled")
        try await app.buttons["passcode-picker"].firstMatch.makeTap(wait: .seconds(0))
        try await app.buttons["passcode-enable"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        if #available(iOS 26.0, *) {
            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        } else {
            try await app.navigationBars.element(boundBy: 4).buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        }
        XCTAssertEqual(app.buttons["passcode-picker"].firstMatch.label, "Enabled")
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        try await app.collectionViews["sidebar"].firstMatch.cells.element(boundBy: 1).makeTap(wait: .seconds(0))
        try await app.collectionViews["sidebar"].firstMatch.cells.element(boundBy: 0).makeTap(wait: .seconds(0))
        XCTAssertEqual(app.staticTexts["select-playlist"].firstMatch.label, "Select a playlist")
        try await app.textFields["passcode-input"].firstMatch.makeTap().typeText(passcode)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.collectionViews["content"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
    }
    
    private func iPhone(app: XCUIApplication, playlistId: Int) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .phone)
        continueAfterFailure = true
        let playlists = try await apiClient.config().playlists
        let playlist = playlists[playlistId]
        do {
            if let somePlaylist = playlists.first(where: { $0.url != playlist.url }) {
                try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(1))
                try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.name)
                try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.url)
                try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.tvgLogo)
                try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
            }
        }
        let passcode = "123456"
        try await app.buttons["add"].firstMatch.makeTap()
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "add-playlist-blank"), app: app, localized: false)
        try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
        try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
        try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
        try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
        try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
        try await app.textFields["passcode"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "add-playlist-filled"), app: app, localized: false)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlists"), app: app, localized: false)
        // Last added always first in a list.
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Movies")
        try await app.cells.firstMatch.makeTap(wait: .seconds(1))
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Movies")
        try await app.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode.dropLast(2)))
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "passcode-input"), app: app, localized: false)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.alerts.firstMatch.staticTexts.element(boundBy: 1).label, "Enter the correct playlist PIN.")
        try await app.buttons["ok"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode.dropFirst(4)))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist"), app: app, localized: false, precision: 0.9992)
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.buttons["passcode-picker"].firstMatch.label, "Enabled")
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "settings"), app: app, localized: false)
        try await app.buttons["passcode-picker"].firstMatch.makeTap(wait: .seconds(0))
        try await app.buttons["passcode-disable"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        if #available(iOS 26.0, *) {
            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        } else {
            try await app.navigationBars.element(boundBy: 2).buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        }
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        if #available(iOS 26.0, *) {
            try await app.buttons["BackButton"].firstMatch.makeTap(wait: .seconds(0))
        } else {
            try await app.navigationBars.firstMatch.buttons.firstMatch.makeTap(wait: .seconds(1))
        }
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Movies")
        try await app.cells.element(boundBy: 0).makeTap(wait: .seconds(0))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.buttons["passcode-picker"].firstMatch.label, "Disabled")
        try await app.buttons["passcode-picker"].firstMatch.makeTap(wait: .seconds(0))
        try await app.buttons["passcode-enable"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        if #available(iOS 26.0, *) {
            try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        } else {
            try await app.navigationBars.element(boundBy: 2).buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        }
        XCTAssertEqual(app.buttons["passcode-picker"].firstMatch.label, "Enabled")
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        if #available(iOS 26.0, *) {
            try await app.buttons["BackButton"].firstMatch.makeTap(wait: .seconds(0))
        } else {
            try await app.navigationBars.firstMatch.buttons.firstMatch.makeTap(wait: .seconds(1))
        }
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Movies")
        try await app.cells.element(boundBy: 0).makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap().typeText(passcode)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
    }
#endif
#if os(tvOS)
    private func tvOS(app: XCUIApplication, playlistCount: Int) async throws {
        XCTAssert(UIDevice.current.userInterfaceIdiom == .tv)
        continueAfterFailure = true
        func openSettings() async throws {
            XCUIRemote.shared.press(.select, forDuration: 1)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.select)
            try await Task.sleep(for: .seconds(1))
        }
        try await Task.sleep(for: .seconds(1))
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlists"), app: app, localized: false, precision: 0.999)
        for _ in 0..<playlistCount {
            XCUIRemote.shared.press(.down)
        }
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(2))
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "add-playlist-blank"), app: app, localized: false, precision: 0.999)
        XCUIRemote.shared.press(.menu)
        try await Task.sleep(for: .seconds(1))
        for _ in 0..<playlistCount {
            XCUIRemote.shared.press(.up)
        }
        try await openSettings()
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "settings"), app: app, localized: false, precision: 0.999)
        XCUIRemote.shared.press(.menu)
        try await Task.sleep(for: .seconds(1))
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(1))
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.hasFocus, true)
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.buttons.firstMatch.label, "Comedy, Vacation")
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        
        XCTAssertEqual(app.scrollViews["program-list"].firstMatch.buttons.element(boundBy: 0).label, "15:00 - 17:00: 21 Jump Street")
        XCTAssertEqual(app.scrollViews["program-list"].firstMatch.buttons.element(boundBy: 1).label, "17:00 - 19:00: Palm Springs")
        XCTAssertEqual(app.scrollViews["program-list"].firstMatch.buttons.element(boundBy: 2).label, "19:00 - 21:00: Vacation")
        
        XCUIRemote.shared.press(.down)
        try await Task.sleep(for: .seconds(1))
        
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.hasFocus, false)
        XCTAssertEqual(app.tables.firstMatch.cells.element(boundBy: 1).hasFocus, true)
        XCTAssertEqual(app.tables.firstMatch.cells.element(boundBy: 1).buttons.firstMatch.label, "Action, Top Gun")
        XCTAssertEqual(app.tables.firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).label, "Action")
        XCTAssertEqual(app.tables.firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 1).label, "Top Gun")
        
        XCTAssertEqual(app.scrollViews["program-list"].firstMatch.buttons.element(boundBy: 0).label, "15:00 - 17:00: Mad Max")
        XCTAssertEqual(app.scrollViews["program-list"].firstMatch.buttons.element(boundBy: 1).label, "17:00 - 19:00: The Dark Knight")
        XCTAssertEqual(app.scrollViews["program-list"].firstMatch.buttons.element(boundBy: 2).label, "19:00 - 21:00: Top Gun")
        
        try await Task.sleep(for: .seconds(1))
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "stream"), app: app, localized: false, precision: 0.998)
        
        XCUIRemote.shared.press(.menu)
        try await Task.sleep(for: .seconds(1))
        try await openSettings()
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(1))
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(1))
        
        func enterPasscode() async throws {
            XCTAssertEqual(app.textFields["passcode-input"].firstMatch.hasFocus, true)
            XCUIRemote.shared.press(.select)
            try await Task.sleep(for: .seconds(1))
            for _ in 0...3 {
                XCUIRemote.shared.press(.select) // select 'a'
            }
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down) // 'done'
            XCUIRemote.shared.press(.select)
            try await Task.sleep(for: .seconds(1))
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.right)
            XCUIRemote.shared.press(.select) // 'done'
            try await Task.sleep(for: .seconds(1))
        }
        
        snapshotUtils.assertSnapshot(named: env.snapshotName(context: "passcode-input"), app: app, localized: false, precision: 0.999)
        try await enterPasscode()
        if #available(tvOS 26.0, *) {
            XCUIRemote.shared.press(.right)
        } else {
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
        }
        XCUIRemote.shared.press(.select) // 'done'
        try await Task.sleep(for: .seconds(1))
        
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(1))
        try await enterPasscode()
        
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.hasFocus, true)
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.buttons.firstMatch.label, "Comedy, Vacation")
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
        
        XCUIRemote.shared.press(.menu)
        try await Task.sleep(for: .seconds(1))
        try await openSettings()
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.up)
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(1))
        XCUIRemote.shared.press(.down)
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(1))
        
        try await enterPasscode()
        if #available(tvOS 26.0, *) {
            XCUIRemote.shared.press(.right)
        } else {
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
            XCUIRemote.shared.press(.down)
        }
        XCUIRemote.shared.press(.select) // 'done'
        try await Task.sleep(for: .seconds(1))
        
        XCUIRemote.shared.press(.select)
        try await Task.sleep(for: .seconds(2))
        
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.hasFocus, true)
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.buttons.firstMatch.label, "Comedy, Vacation")
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).label, "Comedy")
        XCTAssertEqual(app.tables.firstMatch.cells.firstMatch.staticTexts.element(boundBy: 1).label, "Vacation")
    }
#endif
#if os(macOS)
    private func macOS(app: XCUIApplication, playlistId: Int) async throws {
        continueAfterFailure = true
        try await Task.sleep(for: .seconds(2))
        let playlists = try await apiClient.config().playlists
        let playlist = playlists[playlistId]
        do {
            if let somePlaylist = playlists.first(where: { $0.url != playlist.url }) {
                try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(0))
                try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.name)
                try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.url)
                try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(somePlaylist.tvgLogo)
                try await app.sheets.firstMatch.buttons["add"].firstMatch.makeTap(wait: .seconds(0))
            }
        }
        let passcode = "123456"
        try await app.buttons["add"].firstMatch.makeTap(wait: .seconds(2))
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(context: "add-playlist-blank"), app: app, localized: false, precision: 0.97)
        try await app.textFields["name"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.name)
        try await app.textFields["url"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.url)
        try await app.textFields["tvg-logo"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.tvgLogo)
        try await app.textFields["url-tvg"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlTvg)
        try await app.textFields["url-img"].firstMatch.makeTap(wait: .seconds(0)).typeText(playlist.urlImg)
        try await app.textFields["passcode"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        try await Task.sleep(for: .seconds(1))
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(context: "add-playlist-filled"), app: app, localized: false, precision: 0.97)
        try await app.sheets.firstMatch.buttons["add"].firstMatch.makeTap(wait: .seconds(1))
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlists"), app: app, localized: false)
        // Last added always first in a list.
        XCTAssertEqual(app.outlines["sidebar"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).value as? String, "Movies")
        try await app.outlines["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.buttons["cancel"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.staticTexts["select-playlist"].firstMatch.value as? String, "Select a playlist")
        XCTAssertEqual(app.outlines["sidebar"].firstMatch.cells.firstMatch.staticTexts.element(boundBy: 0).value as? String, "Movies")
        try await app.outlines["sidebar"].firstMatch.cells.firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode.dropLast(2)))
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(context: "passcode-input"), app: app, localized: false)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        try await app.buttons["ok"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(String(passcode.dropFirst(4)))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Comedy")
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 1).value as? String, "Vacation")
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(context: "playlist"), app: app, localized: false)
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.popUpButtons["passcode-picker"].firstMatch.value as? String, "Enabled")
        try await snapshotUtils.assertSnapshot(named: env.snapshotName(context: "settings"), app: app, localized: false)
        try await app.popUpButtons["passcode-picker"].firstMatch.makeTap(wait: .seconds(0))
        try await app.menuItems["passcode-disable"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        try await app.sheets.element(boundBy: 1).buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Comedy")
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 1).value as? String, "Vacation")
        try await app.outlines["sidebar"].firstMatch.cells.element(boundBy: 1).makeTap(wait: .seconds(0))
        try await app.outlines["sidebar"].firstMatch.cells.element(boundBy: 0).makeTap(wait: .seconds(0))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Comedy")
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 1).value as? String, "Vacation")
        try await app.buttons["settings"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.popUpButtons["passcode-picker"].firstMatch.value as? String, "Disabled")
        try await app.popUpButtons["passcode-picker"].firstMatch.makeTap(wait: .seconds(0))
        try await app.menuItems["passcode-enable"].firstMatch.makeTap(wait: .seconds(0))
        try await app.textFields["passcode-input"].firstMatch.makeTap(wait: .seconds(0)).typeText(passcode)
        try await app.sheets.element(boundBy: 1).buttons["confirm"].firstMatch.makeTap(wait: .seconds(1))
        try await app.sheets.firstMatch.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Comedy")
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 1).value as? String, "Vacation")
        try await app.outlines["sidebar"].firstMatch.cells.element(boundBy: 1).makeTap(wait: .seconds(0))
        try await app.outlines["sidebar"].firstMatch.cells.element(boundBy: 0).makeTap(wait: .seconds(0))
        XCTAssertEqual(app.staticTexts["select-playlist"].firstMatch.value as? String, "Select a playlist")
        try await app.textFields["passcode-input"].firstMatch.makeTap().typeText(passcode)
        try await app.buttons["confirm"].firstMatch.makeTap(wait: .seconds(0))
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 0).value as? String, "Comedy")
        XCTAssertEqual(app.outlines["content"].firstMatch.cells.element(boundBy: 1).staticTexts.element(boundBy: 1).value as? String, "Vacation")
    }
#endif
}
