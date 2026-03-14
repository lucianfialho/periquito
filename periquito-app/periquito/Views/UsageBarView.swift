import SwiftUI

struct UsageBarView: View {
    let usage: QuotaPeriod?
    let isLoading: Bool
    let error: String?
    var compact: Bool = false
    var isEnabled: Bool = AppSettings.isUsageEnabled
    var onConnect: (() -> Void)?
    var onRetry: (() -> Void)?

    private var isStale: Bool {
        error != nil && usage != nil
    }

    private var effectivePercentage: Int {
        guard let usage, !usage.isExpired else { return 0 }
        return usage.usagePercentage
    }

    private var usageColor: Color {
        guard usage != nil else { return TerminalColors.dimmedText }
        if isStale { return TerminalColors.dimmedText }
        switch effectivePercentage {
        case ..<50: return TerminalColors.green
        case ..<80: return TerminalColors.amber
        default: return TerminalColors.red
        }
    }

    var body: some View {
        if !isEnabled {
            Button(action: { onConnect?() }) {
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 10))
                    Text("Tap to show Claude usage")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(TerminalColors.dimmedText)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.top, 3)
            .padding(.leading, 2)
            .padding(.bottom, -7)
        } else {
            connectedView
        }
    }

    private var connectedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let error, usage == nil {
                    Button(action: { onRetry?() }) {
                        HStack(spacing: 4) {
                            Text(error)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(TerminalColors.dimmedText)
                            Text("(tap to retry)")
                                .font(.system(size: 10))
                                .foregroundColor(TerminalColors.dimmedText)
                        }
                    }
                    .buttonStyle(.plain)
                } else if let usage, let resetTime = usage.formattedResetTime {
                    HStack(spacing: 4) {
                        Text("Resets in \(resetTime)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(TerminalColors.secondaryText)
                        if isStale {
                            Button(action: { onConnect?() }) {
                                Text("(tap to reconnect)")
                                    .font(.system(size: 10))
                                    .foregroundColor(TerminalColors.dimmedText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("Claude Usage")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(TerminalColors.secondaryText)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else if usage != nil {
                    Text("\(effectivePercentage)%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(usageColor)
                }
            }

            progressBar
        }
        .padding(.top, compact ? 0 : 5)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(TerminalColors.subtleBackground)

                if usage != nil {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(usageColor)
                        .frame(width: geometry.size.width * Double(effectivePercentage) / 100)
                }
            }
        }
        .frame(height: 4)
    }

}
