import SwiftUI

/// Types on the TV using the phone's own keyboard: every character you enter is sent
/// immediately as an Android key event, and deleting sends a delete key. Nothing is
/// batched, so the TV mirrors what you type as you type it.
struct KeyboardSheet: View {
    let controller: RemoteController

    @State private var text = ""
    @State private var status: String?
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Type — the TV follows along", text: $text)
                    .focused($focused)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.textPrimary)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.surfaceRaised))
                    .onChange(of: text) { old, new in transmit(from: old, to: new) }
                    .onSubmit { fire(CharacterKeys.enter) }
                    .submitLabel(.search)

                Text(status ?? "Focus a search box on the TV first.")
                    .font(.system(size: 12))
                    .foregroundStyle(status == nil ? Color.textMuted : Color.textSecondary)

                HStack(spacing: 10) {
                    action("Backspace", "delete.left") { fire(CharacterKeys.delete) }
                    action("Space", "space") { fire(CharacterKeys.space) }
                    action("Enter", "return") { fire(CharacterKeys.enter) }
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

    /// Sends only the difference, so holding backspace or typing fast stays in step.
    private func transmit(from old: String, to new: String) {
        if new.count < old.count {
            for _ in 0..<(old.count - new.count) { fire(CharacterKeys.delete) }
            return
        }
        guard new.hasPrefix(old) else {
            // Non-append edit (paste, autocorrect): clear the field and retype it.
            for _ in 0..<old.count { fire(CharacterKeys.delete) }
            send(String(new))
            return
        }
        send(String(new.dropFirst(old.count)))
    }

    private func send(_ fragment: String) {
        let unsupported = CharacterKeys.unsupported(in: fragment)
        guard unsupported.isEmpty else {
            status = "Can't type \(unsupported.map(String.init).joined(separator: " "))"
            return
        }
        for character in fragment {
            guard let code = CharacterKeys.code(for: character) else { continue }
            fire(code)
        }
    }

    private func fire(_ code: UInt64) {
        status = nil
        Task {
            do {
                try await controller.transport.sendKeyCode(code)
            } catch {
                status = (error as? LocalizedError)?.errorDescription ?? "Not connected"
            }
        }
    }

    private func action(_ label: String, _ symbol: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
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
