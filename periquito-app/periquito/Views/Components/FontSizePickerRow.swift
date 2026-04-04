import SwiftUI

struct FontSizePickerRow: View {
    @Binding var selected: AppSettings.FontSize

    var body: some View {
        SettingsRowView(icon: "textformat.size", title: "Font Size") {
            HStack(spacing: 4) {
                ForEach(AppSettings.FontSize.allCases, id: \.rawValue) { size in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = size
                            AppSettings.fontSize = size
                        }
                    }) {
                        Text(size.label)
                            .font(.system(size: 11, weight: selected == size ? .bold : .regular))
                            .foregroundColor(selected == size ? TerminalColors.primaryText : TerminalColors.dimmedText)
                            .frame(width: 28, height: 22)
                            .background(selected == size ? Color.white.opacity(0.15) : Color.clear)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
