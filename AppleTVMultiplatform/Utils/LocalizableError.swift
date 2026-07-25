
import Foundation

struct LocalizableError: LocalizedError, ExpressibleByStringLiteral, Equatable {

    let error: NSError

    var errorDescription: String? {
        error.localizedDescription
    }

    var failureReason: String? {
        error.localizedFailureReason
    }

    var recoverySuggestion: String? {
        error.localizedRecoverySuggestion
    }

    var helpAnchor: String? {
        error.helpAnchor
    }

    static func == (lhs: LocalizableError, rhs: LocalizableError) -> Bool {
        lhs.error == rhs.error
    }
}

extension LocalizableError {

    init(error: Swift.Error) {
        self.error = error as NSError
    }

    init(error: String) {
        self.init(error: NSError(domain: "com.app.error", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))
    }

    init(stringLiteral value: String) {
        self.init(error: value)
    }
}