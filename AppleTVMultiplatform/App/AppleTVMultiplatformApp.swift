
import SwiftUI
import SwiftData
import FactoryKit

// Only for builds from Fastlane for releases.
#if FirebaseSupport
import Firebase
    #if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FirebaseApp.configure()
    }
}
    #else
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}
    #endif
#endif

@main
struct AppleTVMultiplatformApp: App {

#if FirebaseSupport
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif
#endif
    @State private var viewModel = AppleTVMultiplatformAppViewModel()
    @State private var playlistListUpdate: UUID = .init()
    @InjectedObservable(\.logger) var logger

    var body: some Scene {
        WindowGroup {
            ContentView(playlistListUpdate: $playlistListUpdate)
#if os(macOS) && DEBUG
                .modifier(SnapshotTestScreenSizeRatioViewModifier())
#endif
                .onAppear {
                    logger.info("App started")
                }
                .onOpenURL { url in
                    logger.info("App Open URL", private: url)
                    if viewModel.handleIncomingFile(url: url) {
                        playlistListUpdate = .init()
                    }
                }
                .alert(isPresented: $viewModel.isErrorPresented, error: viewModel.error, actions: {
                    Button("OK", role: .cancel) { }
                })
        }
    }
}

#if os(macOS) && DEBUG
private struct SnapshotTestScreenSizeRatioViewModifier: ViewModifier {

    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.arguments.contains("--window-fixed-size") {
            content
                .frame(
                    minWidth: 1280,
                    maxWidth: 1280,
                    minHeight: 748,
                    maxHeight: 748
                )
        } else {
            content
        }
    }
}
#endif
