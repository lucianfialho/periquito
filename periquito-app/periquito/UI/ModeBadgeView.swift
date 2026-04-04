import SwiftUI

struct ModeBadgeView: View {
    let mode: String

    var color: Color {
        switch mode {
        case "Plan Mode":
            TerminalColors.planMode
        case "Accept Edits":
            TerminalColors.acceptEdits
        default:
            TerminalColors.secondaryText
        }
    }

    var body: some View {
        Text(mode)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
    }
}
