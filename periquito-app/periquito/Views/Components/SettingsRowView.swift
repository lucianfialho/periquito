import SwiftUI

struct SettingsRowView<Trailing: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let trailing: () -> Trailing

    private var fontSize: CGFloat { AppSettings.fontSize.settingsFont }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: fontSize))
                .foregroundColor(TerminalColors.secondaryText)
                .frame(width: 20)

            Text(title)
                .font(.system(size: fontSize))
                .foregroundColor(TerminalColors.primaryText)

            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
