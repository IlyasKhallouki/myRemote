import SwiftUI

struct SettingsSheet: View {
    let controller: RemoteController
    let macros: MacroService

    @State private var baseURL: String = ""
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
}
