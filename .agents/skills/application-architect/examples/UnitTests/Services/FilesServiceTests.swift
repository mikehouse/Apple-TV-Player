import Testing
import FactoryKit
import FactoryTesting
@testable import MyApp

struct FilesServiceTests {

    private let service = FilesService()

    @Test func list() async throws {
        let files = await service.list(FileManager.default.temporaryDirectory)
        #expect(files == [])
    }
}