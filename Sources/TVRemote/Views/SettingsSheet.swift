import SwiftUI

struct SettingsSheet: View {
    let controller: RemoteController
    let macros: MacroService

    @State private var baseURL: String = ""
    @State private var credential: String = ""
    @State private var credentialError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.10:8080", text: $baseURL)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .font(.system(size: 15))
                        .foregroundStyle(Color.textPrimary)
                } header: {
                    Text("Macro server")
                        .foregroundStyle(Color.textMuted)
                } footer: {
                    Text("Leave empty to disable macros.")
                        .foregroundStyle(Color.textMuted)
                }
                .listRowBackground(Color.surfaceRaised)

                Section {
                    if Credentials.isStored {
                        HStack {
                            Text("Paired")
                                .font(.system(size: 15))
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            Button("Remove") {
                                Credentials.remove()
                                credential = ""
                            }
                            .foregroundStyle(.red)
                        }
                    } else {
                        TextField("base64 of client.p12", text: $credential, axis: .vertical)
                            .lineLimit(3)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.textPrimary)
                        Button("Import credential") { importCredential() }
                            .foregroundStyle(Color.accentText)
                            .disabled(credential.isEmpty)
                    }
                    if let credentialError {
                        Text(credentialError)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("TV credential")
                        .foregroundStyle(Color.textMuted)
                }
                .listRowBackground(Color.surfaceRaised)

                Section {
                    NavigationLink("Debug") {
                        DebugView(controller: controller)
                    }
                    .foregroundStyle(Color.textPrimary)
                }
                .listRowBackground(Color.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        macros.baseURL = baseURL
                        dismiss()
                    }
                }
            }
        }
        .onAppear { baseURL = macros.baseURL }
    }

    private func importCredential() {
        credentialError = nil
        let cleaned = credential.filter { !$0.isWhitespace }
        guard let data = Data(base64Encoded: cleaned) else {
            credentialError = "Not valid base64."
            return
        }
        do {
            try Credentials.store(data)
            credential = ""
        } catch {
            credentialError = (error as? LocalizedError)?.errorDescription ?? "\(error)"
        }
    }
}
