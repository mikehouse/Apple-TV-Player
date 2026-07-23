
import FactoryKit
import SwiftUI

#if os(iOS)

struct AppSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AppSettingsViewModel = AppSettingsViewModel()
    @InjectedObservable(\.logger) var logger

    var body: some View {
        contentView()
            .onChange(of: viewModel.pipEnabled) { _, _ in
                viewModel.onPipChange()
            }
    }

    @ViewBuilder
    private func contentView() -> some View {
        VStack {
            List {
                Section {
                    updatePlaylistOptions()
                }
            }
            Spacer()
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                confirmButtonView()
            }
            ToolbarItem(placement: .cancellationAction) {
                cancelButtonView()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }

    private func cancelButtonView() -> some View {
        CancelButtonView {
            let _ = logger.info("Cancel button event")
            dismiss()
        }
        .disabled(viewModel.hasChanges)
    }

    private func confirmButtonView() -> some View {
        ConfirmButtonView {
            let _ = logger.info("Confirm button event")
            dismiss()
        }
        .disabled(!viewModel.hasChanges)
    }

    private func updatePlaylistOptions() -> some View {
        HStack {
            Image(systemName: "pip")
            Text("Picture in Picture")
            Spacer()
            Toggle("", isOn: $viewModel.pipEnabled)
                .toggleStyle(.switch)
                .accessibilityIdentifier("pip-toggle")
        }
    }
}

    #if DEBUG

struct AppSettingsViewPreviews: PreviewProvider {

    static var previews: some View {
        Text("")
            .sheet(isPresented: .constant(true)) {
                NavigationStack {
                    AppSettingsView()
                }
                .presentationDetents([.medium, .large])
            }
    }
}

    #endif

#endif
