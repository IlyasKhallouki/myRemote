import SwiftUI

struct KeyboardSheet: View {
    let controller: RemoteController

    @State private var text = ""
    @State private var status: String?
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Type for the TV", text: $text)
                    .focused($focused)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.textPrimary)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.surfaceRaised))
                    .onSubmit(send)
                    .submitLabel(.send)

                if let status {
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                } else if !controller.transport.canType {
                    Text("Put the cursor in a search box on the TV, then type here.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textMuted)
                }

                HStack(spacing: 10) {
                    key("Send", symbol: "arrow.up.circle", action: send)
                        .disabled(text.isEmpty)
                    key("Backspace", symbol: "delete.left") {
                        controller.send(.back)
                    }
                    key("Clear", symbol: "xmark.circle") {
                        text = ""
                        status = nil
                    }
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.background)
            .navigationTitle("Keyboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { focused = true }
    }

    private func send() {
        let payload = text
        guard !payload.isEmpty else { return }
        Task {
            do {
                try await controller.transport.sendText(payload)
                status = "Sent \"\(payload)\""
                text = ""
            } catch {
                status = (error as? LocalizedError)?.errorDescription ?? "Could not send"
            }
        }
    }

    private func key(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 17))
                Text(label).font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.surfaceRaised))
            .foregroundStyle(Color.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
