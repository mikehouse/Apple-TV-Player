import Foundation
import FactoryKit
import SwiftUI
import SwiftData

@Observable
final class AppSettingsViewModel {

    @ObservationIgnored @Injected(\.databaseService) private var databaseService
    @ObservationIgnored @Injected(\.logger) private var logger

    private var initialStates: States = .init(pipEnabled: false)

    private(set) var hasChanges: Bool = false

#if os(iOS)

    var pipEnabled: Bool = false

    init() {
        let fetch = FetchDescriptor<AppSettings>()
        pipEnabled = (try? databaseService.mainContext.fetch(fetch))?.first?.iOSPictureInPictureEnabled ?? true
        initialStates = States(pipEnabled: pipEnabled)
    }

    func onPipChange() {
        let fetch = FetchDescriptor<AppSettings>()
        var settings = (try? databaseService.mainContext.fetch(fetch))?.first
        if settings == nil {
            settings = AppSettings(iOSPictureInPictureEnabled: pipEnabled)
            databaseService.mainContext.insert(settings!)
        } else {
            settings?.iOSPictureInPictureEnabled = pipEnabled
        }
        try? databaseService.mainContext.save()
        logger.info("set picture in picture to \(pipEnabled)")
        updateChanges()
    }

#endif

    private func updateChanges() {
#if os(iOS)
        hasChanges = States(pipEnabled: pipEnabled) != initialStates
#endif
    }

    private struct States: Equatable {
        var pipEnabled: Bool
    }

    isolated deinit {
        logger.info("deinit of \(self)")
    }
}