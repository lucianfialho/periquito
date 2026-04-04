import SwiftUI

struct TypingIndicatorView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("🦜")
                .font(.system(size: 14))

            TimelineView(.periodic(from: .now, by: 0.4)) { timeline in
                let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 0.4) % 3

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        let distance = min(abs(index - phase), 3 - abs(index - phase))

                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 5, height: 5)
                            .opacity(distance == 0 ? 1.0 : (distance == 1 ? 0.5 : 0.2))
                            .animation(.easeInOut(duration: 0.3), value: phase)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12, corners: [.topLeft, .topRight, .bottomRight])

            Spacer()
        }
    }
}
