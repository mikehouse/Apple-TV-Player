
import Foundation

struct StringIdentifiable: Identifiable, ExpressibleByStringLiteral, Sendable {
    
    let string: String

    init(stringLiteral value: String) {
        self.string = value
    }
    
    init(string: String) {
        self.string = string
    }

    var id: String { string }
}
