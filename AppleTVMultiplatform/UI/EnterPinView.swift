
import SwiftUI

struct EnterPinView: View {

    @Binding var pin: String
    let okAction: () -> Void
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack {
                Spacer()
                Text("Passcode")
                    .font(.headline)
                Spacer()
            }
            TextField("", text: $pin)
                .accessibilityIdentifier("passcode-input")
                .autocorrectionDisabled()
                .focused($isTextFieldFocused)
                .onAppear {
                    isTextFieldFocused = true
                }
#if !os(tvOS)
                .textFieldStyle(.roundedBorder)
#endif
#if !os(iOS)
            HStack {
                cancelButton()
                Spacer()
                okButton()
            }
#endif
        }
#if os(tvOS)
        .padding(44)
#else
        .padding()
#endif
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                cancelButton()
            }
            ToolbarItem(placement: .confirmationAction) {
                okButton()
            }
        }
#endif
#if os(macOS)
        .frame(width: 260)
#endif
    }

    private func cancelButton() -> some View {
        CancelButtonView {
            dismiss()
        }
    }

    private func okButton() -> some View {
        HStack {
            ConfirmButtonView {
                okAction()
            }
            .disabled(pin.isEmpty)
        }
    }
}
