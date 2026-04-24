
import Foundation
import XCTest

@MainActor
final class MockAppEnv {

    let port: Int
    let lang: String
    let simId: String
    let osVersion: String
    let deviceType: String
    let langAndLocale: String
    
    private(set) var order = 0

    init() throws {
        guard let portString = ProcessInfo.processInfo.environment["LOCAL_PORT"],
              let port = Int(portString) else {
            throw NSError(
                domain: "MockAppEnv", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing environment variable LOCAL_PORT"])
        }
        let args = ProcessInfo.processInfo.arguments
        guard let language = args.firstIndex(of: "-AppleLanguages").map({ args[$0 + 1].dropFirst().dropLast() }) else {
            throw NSError(
                domain: "MockAppEnv", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing app language argument"])
        }
#if os(macOS)
        guard let simId = ProcessInfo.processInfo.environment["RUN_DESTINATION_DEVICE_UDID"] else {
            throw NSError(
                domain: "MockAppEnv", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing device UDID"])
        }
#else
        guard let simId = ProcessInfo.processInfo.environment["SIMULATOR_UDID"], simId.count == 36 else {
            throw NSError(
                domain: "MockAppEnv", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Missing simulator UDID"])
        }
#endif
        guard let (osVersion, deviceType) = Self.parseSimulatorInfo(from: ProcessInfo.processInfo.environment["SIMULATOR_VERSION_INFO"] ?? "") else {
            throw NSError(
                domain: "MockAppEnv", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't detect simulator capabilities"])
        }
        let renamedLocaleMap: [String: String] = [
            "ar": "ar-SA",
            "de": "de-DE",
            "en": "en-US",
            "es": "es-ES",
            "es-419": "es-MX",
            "fr": "fr-FR"
        ]
        
        self.simId = simId
        self.lang = String(language)
        self.port = port
        self.osVersion = osVersion
        self.deviceType = deviceType
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "-")
        self.langAndLocale = renamedLocaleMap[lang] ?? lang
    }
    
    func snapshotName(dark: Bool = false, context: String) -> String {
        order += 1
        let args: [String] = [
            "\(order)",
            deviceType,
            osVersion,
            dark ? "Dark" : "Light",
            context.capitalized,
            lang
        ]
        return args.joined(separator: "_")
    }

    // "CoreSimulator 1051.49 - Device: My Max pro (717BDF94-1249-484D-8F1F-D132F4CAE122) - Runtime: iOS 26.4 (23E244) - DeviceType: iPhone 17 Pro Max"
    private static func parseSimulatorInfo(from string: String) -> (iOSVersion: String, deviceType: String)? {
#if os(macOS)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let major = osVersion.majorVersion
        return ("\(major)", "macosx")
#else
        let versionPattern = #"Runtime:\s+(?:iOS|tvOS)\s+([\d.]+)"#
        let deviceTypePattern = #"DeviceType:\s+(.+)$"#

        var osVersion: String?
        var deviceType: String?

        if let match = string.range(of: versionPattern, options: .regularExpression) {
            let fullMatch = String(string[match])
            osVersion = fullMatch
                .replacingOccurrences(of: #"Runtime:\s+(?:iOS|tvOS)\s+"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }

        if let match = string.range(of: deviceTypePattern, options: .regularExpression) {
            let fullMatch = String(string[match])
            deviceType = fullMatch
                .replacingOccurrences(of: "DeviceType: ", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        guard let osVersion, let deviceType else { return nil }
        return (osVersion, deviceType)
#endif
    }
}
