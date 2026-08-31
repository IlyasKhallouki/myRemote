import SwiftUI
import TVRemoteCore

struct RemoteView: View {
    private let controller = RemoteController.shared
    private let lockScreen = LockScreenSession.shared

    @State private var macros = MacroService()
    @State private var haptics = Haptics()
    #if canImport(UIKit)
    @State private var hardwareVolume = HardwareVolume()
    #endif
    @State private var showingPicker = false
    @State private var showingSettings = false
    @State private var showingKeyboard = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                StatusPill(
                    title: controller.statusTitle,
                    state: controller.transport.state,
                    simulated: controller.transport.isSimulated
                )
                    .onTapGesture { showingPicker = true }
                Spacer()
            }
            .overlay(alignment: .leading) {
                HStack(spacing: 14) {
                if Preferences.shared.powerKey {
                    Button {
                        send(.power)
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Power")
                }
                Button {
                    Task { await lockScreen.toggle() }
                } label: {
                    Image(systemName: lockScreen.isActive ? "pin.fill" : "pin")
                        .font(.system(size: 17))
                        .foregroundStyle(lockScreen.isActive ? Color.accentText : Color.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lockScreen.isActive ? "Close the Lock Screen remote" : "Pin the remote to the Lock Screen")
                }
            }
            .overlay(alignment: .trailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.textMuted)
                }
                .buttonStyle(.plain)
            }

            if let message = lockScreen.lastError {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            DPadView(send: send)

            TransportRow(send: send, volume: controller.transport.volumeState)

            // Additive on purpose: the drag control above keeps working whether
            // or not the experimental absolute-volume message is understood.
            if Preferences.shared.absoluteVolume, let volume = controller.transport.volumeState, volume.max > 0 {
                AbsoluteVolumeSlider(volume: volume) { level in
                    Task { await controller.setVolume(level: level) }
                }
            }

            MacroGrid(
                macros: Macro.all,
                state: macros.state(for:),
                run: { macro in
                    if case .keyboard = macro.action {
                        showingKeyboard = true
                    } else {
                        Task { await macros.run(macro, using: controller.transport) }
                    }
                }
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPicker) {
            TVPickerSheet(
                discovery: controller.discovery,
                connectedTV: controller.connectedTV
            ) { tv in
                Task { await controller.connect(to: tv) }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingKeyboard) {
            KeyboardSheet(controller: controller)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet(controller: controller, macros: macros)
                .preferredColorScheme(.dark)
        }
        .background {
            #if canImport(UIKit)
            VolumeAnchorView(anchor: hardwareVolume.anchor)
                .frame(width: 1, height: 1)
            #endif
        }
        .task {
            Automations.shared.onTextRequest = { showingKeyboard = true }
            haptics.prepare()
            #if canImport(UIKit)
            hardwareVolume.start { key, count in
                for _ in 0..<count { send(key) }
            }
            #endif
        }
        .onOpenURL { url in
            guard let action = DeepLink.parse(url) else { return }
            switch action {
            case .key(let key):
                haptics.fire()
                Task { await controller.perform(key) }
            case .macro(let id):
                guard let macro = Macro.all.first(where: { $0.id == id }) else { return }
                Task { await macros.run(macro, using: controller.transport) }
            }
        }
        .onChange(of: controller.discovery.televisions.count) { _, found in
            // Discovery is asynchronous: the TV often turns up after the one
            // connect attempt at launch has already given up.
            guard found > 0, !controller.isLive else { return }
            Task { await controller.ensureLive() }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: controller.onForeground()
            case .background:
                controller.onBackground()
                #if canImport(UIKit)
                hardwareVolume.stop()
                #endif
            default: break
            }
        }
    }

    private func send(_ key: RemoteKey) {
        haptics.fire()
        controller.send(key)
    }
}
