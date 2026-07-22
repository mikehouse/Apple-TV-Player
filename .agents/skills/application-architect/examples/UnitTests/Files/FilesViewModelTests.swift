import Testing
import FactoryKit
import FactoryTesting
@testable import MyApp

struct FilesViewModelTests {

    @Test func updateList() async throws {
        final class MockFilesService: FilesServiceInterface {
            func list(_ path: URL) async -> [String] {
                ["1.txt"]
            }
        }

        Container.shared.filesService.register { MockFilesService() }
        let viewModel = FilesViewModel()

        #expect(viewModel.list == [])
        await viewModel.updateList(URL(fileURLWithPath: "/" ))
        #expect(viewModel.list  == ["1.txt"])
    }

    @Test func selectExportDirectory() async throws {
        let viewModel = FilesViewModel()
        #expect(viewModel.isSelectingExportDirectory == false)
        viewModel.selectExportDirectory()
        #expect(viewModel.isSelectingExportDirectory == true)
    }
}