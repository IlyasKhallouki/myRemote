import SwiftUI

struct RemoteView: View {
    @State private var controller = RemoteController()
    @State private var macros = MacroService()
    @State private var haptics = Haptics()
    #if canImport(UIKit)
    @State private var hardwareVolume = HardwareVolume()
    #endif
    @State private var showingPicker = false
    @State private var showingSettings = false

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

            DPadView(send: send)

            TransportRow(send: send, volume: controller.transport.volumeState)

            MacroGrid(
                macros: Macro.all,
                state: macros.state(for:),
                run: { macro in Task { await macros.run(macro, using: controller.transport) } }
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
