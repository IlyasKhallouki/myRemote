import SwiftUI

struct MacroGrid: View {
    let macros: [Macro]
    let state: (Macro) -> MacroState
    let run: (Macro) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Macros")
                .font(.system(size: 12))
                .foregroundStyle(Color.textMuted)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(macros) { macro in
                    MacroCard(macro: macro, state: state(macro)) { run(macro) }
                }
            }
        }
    }
}

struct MacroCard: View {
    let macro: Macro
    let state: MacroState
    let action: () -> Void

    private var foreground: Color {
        macro.accented ? .accentText : .textPrimary
    }

    private var background: Color {
        macro.accented ? .accentWash : .surfaceRaised
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                symbol
                    .frame(height: 22)
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundStyle(captionColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(background))
        }
        .buttonStyle(.plain)
        .disabled(state == .inFlight)
    }

    @ViewBuilder
    private var symbol: some View {
        switch state {
        case .inFlight:
            ProgressView()
                .controlSize(.small)
                .tint(foreground)
        case .succeeded:
            Image(systemName: "checkmark")
                .font(.system(size: 19))
                .foregroundStyle(Color.statusOK)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 19))
                .foregroundStyle(.red)
        case .idle:
            Image(systemName: macro.symbol)
                .font(.system(size: 19))
                .foregroundStyle(foreground)
        }
    }

    private var caption: String {
        if case let .failed(message) = state { return message }
        return macro.label
    }

    private var captionColor: Color {
        if case .failed = state { return .textSecondary }
        return foreground
    }
}
