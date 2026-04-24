
import XCTest

extension XCUIElement {
    
    @discardableResult
    func makeTap(wait: Duration = .seconds(2)) async throws -> XCUIElement {
#if os(tvOS)
        XCUIRemote.shared.press(.select)
#else
        tap()
#endif
        try await Task.sleep(for: wait)
        return self
    }
}
