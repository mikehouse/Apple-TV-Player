
import Foundation
import SwiftData

#if os(iOS)

@Model
final class AppSettings {
    // By default on iOS the PiP is enabled and when an app goes to background
    // the PiP will be automatically activated and on home screen
    // the video player miniature will show up with a video from the app.
    // If user wants to disable PiP, set this value to false. It will
    // pause the video entirely.
    // macOS and tvOS has no automatic PiP.
    var iOSPictureInPictureEnabled: Bool = true

    init(iOSPictureInPictureEnabled: Bool) {
        self.iOSPictureInPictureEnabled = iOSPictureInPictureEnabled
    }
}

#else

@Model
final class AppSettings {

    init() {

    }
}

#endif

