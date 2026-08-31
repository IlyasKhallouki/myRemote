import SwiftUI
import TVRemoteCore
import UserNotifications

struct SettingsSheet: View {
    let controller: RemoteController
    let macros: MacroService

    @State private var baseURL: String = ""
    @State private var credential: String = ""
    @State private var credentialError: String?
    @State private var notificationsRefused = false
    @Environment(\.dismiss) private var dismiss

    private var prefs: Preferences { .shared }
    private var presence: BackgroundPresence { .shared }

    var body: some View {
        NavigationStack {
            Form {
                addressSection
                lockScreenSection
                backgroundSection
                automationSection
                outsideControlSection
                experimentalSection
                macroServerSection
                credentialSection
                debugSection
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

    // MARK: - Lock Screen

    private var lockScreenSection: some View {
        Section {
            toggle("Contextual controls", isOn: Binding(
                get: { prefs.contextualControls },
                set: { prefs.contextualControls = $0 }
            ))
            toggle("Show volume", isOn: Binding(
                get: { prefs.showVolumeOnLockScreen },
                set: { prefs.showVolumeOnLockScreen = $0 }
            ))
            toggle("Power key", isOn: Binding(
                get: { prefs.powerKey },
                set: { prefs.powerKey = $0 }
            ))
        } header: {
            header("Lock Screen")
        } footer: {
            footer("Contextual controls swap the launch macros for rewind, fast forward and next whenever the TV is already inside a media app.")
        }
        .listRowBackground(Color.surfaceRaised)
    }

    // MARK: - Background

    private var backgroundSection: some View {
        Section {
            toggle("Keep watching the TV", isOn: Binding(
                get: { prefs.backgroundWatch },
                set: {
                    prefs.backgroundWatch = $0
                    Automations.shared.syncPresence()
                }
            ))
            LabeledContent {
                Text(presenceStatus)
                    .font(.system(size: 13))
                    .foregroundStyle(presence.isRunning ? Color.statusOK : Color.textMuted)
            } label: {
                Text("Status")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
            }
        } header: {
            header("Background")
        } footer: {
            footer("Holds the app awake so it can see what the TV is doing even when you are not in the app. Everything under Automations needs it. It costs battery, which is why it is off by default — the Lock Screen remote keeps itself awake while it is up regardless.")
        }
        .listRowBackground(Color.surfaceRaised)
    }

    private var presenceStatus: String {
        if let failure = presence.lastFailure { return failure }
        if presence.isRunning {
            return presence.holders.contains(.lockScreen) ? "Awake for the Lock Screen" : "Awake"
        }
        return "Asleep"
    }

    // MARK: - Automations

    private var automationSection: some View {
        Section {
            toggle("Show remote when the TV turns on", isOn: Binding(
                get: { prefs.showRemoteWhenTVTurnsOn },
                set: { enabled in
                    prefs.showRemoteWhenTVTurnsOn = enabled
                    // iOS often refuses a Live Activity started from the
                    // background, and then this automation falls back to a
                    // notification — which needs permission we would otherwise
                    // never have asked for.
                    if enabled { requestNotifications() }
                }
            ))
            toggle("Hide it when the TV turns off", isOn: Binding(
                get: { prefs.hideRemoteWhenTVTurnsOff },
                set: { prefs.hideRemoteWhenTVTurnsOff = $0 }
            ))
            toggle("Offer the keyboard when the TV asks", isOn: Binding(
                get: { prefs.offerKeyboardWhenTVAsks },
                set: { enabled in
                    prefs.offerKeyboardWhenTVAsks = enabled
                    if enabled { requestNotifications() }
                }
            ))
            toggle("Pause the TV during a call", isOn: Binding(
                get: { prefs.pauseTVOnPhoneCall },
                set: { prefs.pauseTVOnPhoneCall = $0 }
            ))
            toggle("Resume it afterwards", isOn: Binding(
                get: { prefs.resumeTVAfterPhoneCall },
                set: { prefs.resumeTVAfterPhoneCall = $0 }
            ))
            .disabled(!prefs.pauseTVOnPhoneCall)

            if notificationsRefused {
                Text("Notifications are turned off for this app, so the keyboard prompt can only appear while the app is open.")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        } header: {
            header("Automations")
        } footer: {
            footer(prefs.backgroundWatch
                ? "The TV reports its power state and tells us the moment a text field takes focus. These react to that."
                : "Turn on Keep watching the TV above for these to work outside the app.")
        }
        .listRowBackground(Color.surfaceRaised)
        .disabled(!prefs.backgroundWatch)
    }

    // MARK: - Outside control

    private var outsideControlSection: some View {
        Section {
            toggle("Allow Shortcuts and Siri", isOn: Binding(
                get: { prefs.allowShortcutsControl },
                set: { prefs.allowShortcutsControl = $0 }
            ))
        } header: {
            header("Outside control")
        } footer: {
            footer("Adds two actions to the Shortcuts app. Control the TV takes a key name (ok, volumeUp, power) or a macro id (xbox, youtube, spotify). Send Link to TV takes a URL and rewrites YouTube and Spotify links into something the TV will open — wrap it in a shortcut that accepts URLs and it appears in the share sheet. Assign either to the Action Button for one-press control.")
        }
        .listRowBackground(Color.surfaceRaised)
    }

    // MARK: - Experimental

    private var experimentalSection: some View {
        Section {
            toggle("Absolute volume", isOn: Binding(
                get: { prefs.absoluteVolume },
                set: { prefs.absoluteVolume = $0 }
            ))
        } header: {
            header("Experimental")
        } footer: {
            footer("Sends a volume level directly instead of stepping. The message shape is inferred from what the TV reports back, not confirmed against it — run Tools/probe-volume-and-power.py against your TV before trusting it.")
        }
        .listRowBackground(Color.surfaceRaised)
    }

    // MARK: - Existing sections

    private var addressSection: some View {
        Section {
            TextField("192.168.11.104", text: Binding(
                get: { prefs.manualHost },
                set: { prefs.manualHost = $0 }
            ))
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.numbersAndPunctuation)
            #endif
            .autocorrectionDisabled()
            .font(.system(size: 15, design: .monospaced))
            .foregroundStyle(Color.textPrimary)
        } header: {
            header("TV address")
        } footer: {
            footer("Skips Bonjour and connects straight to this address. Discovery needs multicast, which many networks drop — if the TV never appears but you know its IP, put it here. Leave empty to discover normally.")
        }
        .listRowBackground(Color.surfaceRaised)
    }

    private var macroServerSection: some View {
        Section {
            TextField("http://192.168.1.10:8080", text: $baseURL)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .font(.system(size: 15))
                .foregroundStyle(Color.textPrimary)
        } header: {
            header("Macro server")
        } footer: {
            footer("Leave empty to disable macros.")
        }
        .listRowBackground(Color.surfaceRaised)
    }

    private var credentialSection: some View {
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
            header("TV credential")
        }
        .listRowBackground(Color.surfaceRaised)
    }

    private var debugSection: some View {
        Section {
            NavigationLink("Debug") {
                DebugView(controller: controller)
            }
            .foregroundStyle(Color.textPrimary)
        }
        .listRowBackground(Color.surfaceRaised)
    }

    // MARK: - Building blocks

    private func toggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(Color.textPrimary)
        }
        .tint(Color.accentText)
    }

    private func header(_ text: String) -> some View {
        Text(text).foregroundStyle(Color.textMuted)
    }

    private func footer(_ text: String) -> some View {
        Text(text).foregroundStyle(Color.textMuted)
    }

    private func requestNotifications() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = (try? await center.requestAuthorization(options: [.alert])) ?? false
            notificationsRefused = !granted
        }
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
