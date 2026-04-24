
import Foundation

extension ProcessInfo {
    var isPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

extension ProcessInfo {
    var isRunningUnitTests: Bool {
        if environment["XCTestConfigurationFilePath"] != nil && environment["XCODE_TEST_PLAN_NAME"] == nil {
            return true
        }
        if NSClassFromString("XCTestCase") != nil {
            return true
        }
        return false
    }

    var isRunningUITests: Bool {
        if environment["XCODE_TEST_PLAN_NAME"] != nil {
            return true
        }
        return false
    }
}
