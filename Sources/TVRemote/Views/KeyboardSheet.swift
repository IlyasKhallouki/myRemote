import SwiftUI
import TVRemoteCore

/// Types on the TV using the phone's own keyboard.
///
/// Two mechanisms, because neither works everywhere. Verified against the panel
/// over adb: raw key events reach the TV (navigation works) but do **not** enter
/// characters into a focused field — the remote service injects them as a remote
/// control, not as a keyboard, so a text field ignores the letters while still
/// honouring enter and delete. That is why typing looked half-broken.
///
/// The IME batch edit is the mechanism that actually carries text, but it only
/// works once the TV has told us which field has focus, and some apps never do.
/// So: use the IME path whenever the counters are there, fall back to key events
/// otherwise, and say plainly which one is in play instead of silently failing.
struct KeyboardSheet: View {
    let controller: RemoteController

    @State private var text = ""
    @State private var status: String?

    /// Everything typed goes through one chain. Each keystroke used to spawn its
    /// own detached task, and tasks have no ordering between them, so typing at
    /// any speed could deliver characters out of sequence.
    @State private var chain: Task<Void, Never>?
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

                Text(status ?? hint)
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

    private var hint: String {
        "Focus a search box on the TV, then type here."
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
        // Always the IME path. Key events reach the TV but are injected as a
        // remote control rather than a keyboard, so a text field ignores the
        // letters; the batch edit is the only mechanism here that carries text.
        //
        // Send the *fragment*, never the whole field: this TV appends a batch
        // edit rather than replacing with it, so resending the full string on
        // every keystroke spelled "linus" as "llilinlinulinus".
        guard !fragment.isEmpty else { return }
        enqueue {
            try await controller.transport.sendText(fragment)
        }
    }

    private func fire(_ code: UInt64) {
        enqueue {
            try await controller.transport.sendKeyCode(code)
        }
    }

    /// Appends to the send chain, so characters reach the TV in the order they
    /// were typed and a failure surfaces without stopping the next keystroke.
    private func enqueue(_ operation: @escaping () async throws -> Void) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            do {
                try await operation()
                status = nil
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
