import SwiftUI
import TVRemoteCore

struct DebugView: View {
    let controller: RemoteController

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        List {
            Section("Discovery") {
                labelled("State", describe(controller.discovery.state))
                labelled("Remembered", controller.discovery.lastKnownServiceName ?? "none")
                labelled("Found", "\(controller.discovery.televisions.count)")
                labelled("Endpoint", endpointDescription)
                labelled("Network", NetworkReachability.shared.summary)
                labelled("Fixed address", Preferences.shared.manualHost.isEmpty
                    ? "none" : Preferences.shared.manualHost)
            }
            .listRowBackground(Color.surfaceRaised)

            if !TransportLog.shared.previousRun.isEmpty {
                Section("Previous run (survives a crash)") {
                    ForEach(Array(TransportLog.shared.previousRun.enumerated()), id: \.offset) { _, message in
                        Text(message)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .listRowBackground(Color.surfaceRaised)
            }

            Section("Transport log") {
                let log = TransportLog.shared.entries
                if !log.isEmpty {
                    ForEach(log.reversed()) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Self.formatter.string(from: entry.timestamp))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.textMuted)
                            Text(entry.message)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                } else {
                    Text("No entries yet")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .listRowBackground(Color.surfaceRaised)
        }
        .scrollContentBackground(.hidden)
        .background(Color.background)
        .navigationTitle("Debug")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var endpointDescription: String {
        guard let tv = controller.connectedTV else { return "not connected" }
        let host = tv.host ?? "unresolved"
        let port = tv.port.map(String.init) ?? "-"
        return "\(host):\(port)"
    }

    private func describe(_ state: DiscoveryState) -> String {
        switch state {
        case .idle: "idle"
        case .browsing: "browsing"
        case .permissionDenied: "permission denied"
        case .failed(let message): "failed: \(message)"
        }
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.textPrimary)
        }
    }
}
