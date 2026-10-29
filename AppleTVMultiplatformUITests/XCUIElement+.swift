
import XCTest

extension XCUIElement {
    
    @discardableResult
    func makeTap(wait: Duration = .seconds(2), coordinate: CGVector? = nil) async throws -> XCUIElement {
#if os(tvOS)
        XCUIRemote.shared.press(.select)
#elseif os(macOS)
        if let coordinate {
            self.coordinate(withNormalizedOffset: coordinate)
                .click()
        } else {
            click()
        }
#else
        tap()
#endif
        try await Task.sleep(for: wait)
        return self
    }
}
