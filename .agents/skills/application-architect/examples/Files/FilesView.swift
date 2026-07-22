import SwiftUI

struct FilesView: View {

    @State private var viewModel = FilesViewModel()
    // Declare this Binding inside view as it is for parent view.
    @Binding var selectedDirectory: URL?

    var body: some View {
        Group {
            List(viewModel.list, id: \.self) {
                Text($0)
            }
            Button {
                // We change `isSelectingExportDirectory` via view model function
                // to be able to test this behaviour without view in tests.
                viewModel.selectExportDirectory()
            } label: {
                Text("Select directory")
            }
        }
        .task {
            await viewModel.updateList(FileManager.default.temporaryDirectory)
        }
        .fileImporter(
            // This binding declare in ViewModel because ParentView does not need it and does not know about it at all.
            isPresented: $viewModel.isSelectingExportDirectory,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let directoryURL = urls.first else {
                    return
                }
                Task {
                    await viewModel.updateList(directoryURL)
                }
                selectedDirectory = directoryURL
            case .failure(let error):
                print(error)
            }
        }
    }
}

#Preview {
    let _ = Container.shared.filesService.register { FilesServiceMock() }
    FilesView(selectedDirectory: .constant(nil))
}
private actor FilesServiceMock: FilesServiceInterface {
    func list(_ path: URL) async -> [String] { [] }
}