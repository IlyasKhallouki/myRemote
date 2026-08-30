import SwiftUI

struct TVPickerSheet: View {
    let discovery: DiscoveryService
    let connectedTV: DiscoveredTV?
    let select: (DiscoveredTV) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                switch discovery.state {
                case .permissionDenied:
                    deniedRow
                case .failed(let message):
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.textSecondary)
                        .listRowBackground(Color.surfaceRaised)
                case .idle, .browsing:
                    if discovery.televisions.isEmpty {
                        Text("Searching for TVs…")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textSecondary)
                            .listRowBackground(Color.surfaceRaised)
                    } else {
                        ForEach(discovery.televisions) { tv in
                            row(tv)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle("Choose TV")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var deniedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Local network access denied")
                .font(.system(size: 13))
                .foregroundStyle(Color.textPrimary)
            Text("Enable it in Settings › Privacy › Local Network to find your TV.")
                .font(.system(size: 12))
                .foregroundStyle(Color.textSecondary)
        }
        .listRowBackground(Color.surfaceRaised)
    }

    private func row(_ tv: DiscoveredTV) -> some View {
        Button {
            select(tv)
            dismiss()
        } label: {
            HStack {
                Text(tv.serviceName)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                if tv.serviceName == connectedTV?.serviceName {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.statusOK)
                }
            }
        }
        .listRowBackground(Color.surfaceRaised)
    }
}
