import FactoryKit
import FactoryTesting
import Foundation
import SwiftData
import Testing
@testable import Bro_Player

@Suite(.container)
struct AppSettingsViewModelTests {

#if os(iOS)
    @Test func initDefaultsPictureInPictureToEnabledWhenSettingsAreMissing() throws {
        let database = try makeDatabaseService()
        Container.shared.databaseService.register { database }

        let viewModel = AppSettingsViewModel()

        #expect(viewModel.pipEnabled == true)
        #expect(viewModel.hasChanges == false)
        #expect(try fetchSettings(from: database).isEmpty)
    }

    @Test func initLoadsStoredPictureInPictureSetting() throws {
        let database = try makeDatabaseService(
            pictureInPictureEnabled: false
        )
        Container.shared.databaseService.register { database }

        let viewModel = AppSettingsViewModel()

        #expect(viewModel.pipEnabled == false)
        #expect(viewModel.hasChanges == false)
    }

    @Test func onPipChangeCreatesMissingSettingAndMarksChanges() throws {
        let database = try makeDatabaseService()
        Container.shared.databaseService.register { database }
        let viewModel = AppSettingsViewModel()
        viewModel.pipEnabled = false

        viewModel.onPipChange()

        let settings = try fetchSettings(from: database)
        let storedSetting = try #require(settings.first)

        #expect(settings.count == 1)
        #expect(storedSetting.iOSPictureInPictureEnabled == false)
        #expect(viewModel.hasChanges == true)
    }

    @Test func onPipChangeUpdatesStoredSettingAndTracksReversion() throws {
        let database = try makeDatabaseService(
            pictureInPictureEnabled: false
        )
        Container.shared.databaseService.register { database }
        let viewModel = AppSettingsViewModel()
        viewModel.pipEnabled = true

        viewModel.onPipChange()

        var settings = try fetchSettings(from: database)

        #expect(settings.count == 1)
        #expect(settings.first?.iOSPictureInPictureEnabled == true)
        #expect(viewModel.hasChanges == true)

        viewModel.pipEnabled = false
        viewModel.onPipChange()
        settings = try fetchSettings(from: database)

        #expect(settings.count == 1)
        #expect(settings.first?.iOSPictureInPictureEnabled == false)
        #expect(viewModel.hasChanges == false)
    }
#endif
}

#if os(iOS)
private extension AppSettingsViewModelTests {

    func makeDatabaseService(
        pictureInPictureEnabled: Bool? = nil
    ) throws -> DatabaseService {
        let database = DatabaseService(isStoredInMemoryOnly: true)

        if let pictureInPictureEnabled {
            database.mainContext.insert(
                AppSettings(
                    iOSPictureInPictureEnabled: pictureInPictureEnabled
                )
            )
            try database.mainContext.save()
        }

        return database
    }

    func fetchSettings(
        from database: DatabaseService
    ) throws -> [AppSettings] {
        try database.mainContext.fetch(FetchDescriptor<AppSettings>())
    }
}
#endif
