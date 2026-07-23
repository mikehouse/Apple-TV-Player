import FactoryKit
import FactoryTesting
import Foundation
import SwiftData
import Testing
@testable import Bro_Player

@Suite(.container)
struct StreamViewModelTests {

#if os(iOS)
    @Test func pictureInPictureEnabledDefaultsToTrueWhenSettingsAreMissing() {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        Container.shared.databaseService.register { database }
        let viewModel = makeViewModel()

        #expect(viewModel.pictureInPictureEnabled == true)
    }

    @Test func pictureInPictureEnabledUsesStoredSetting() throws {
        let database = DatabaseService(isStoredInMemoryOnly: true)
        database.mainContext.insert(
            AppSettings(iOSPictureInPictureEnabled: false)
        )
        try database.mainContext.save()
        Container.shared.databaseService.register { database }
        let viewModel = makeViewModel()

        #expect(viewModel.pictureInPictureEnabled == false)
    }
#endif
}

private extension StreamViewModelTests {

    func makeViewModel() -> StreamViewModel {
        StreamViewModel(
            content: PlaylistItem.Content(
                identity: .init(
                    name: "Playlist",
                    date: Date(timeIntervalSince1970: 1)
                ),
                url: Data(),
                data: Data(),
                isStoredInMemoryOnly: true
            ),
            stream: PlaylistParser.Stream(
                title: "Stream",
                url: "https://example.com/stream.m3u8",
                tvgLogo: nil,
                tvgID: nil,
                tvgName: nil,
                groupTitle: nil
            )
        )
    }
}
