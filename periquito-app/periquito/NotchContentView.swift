import SwiftUI

enum NotchConstants {
    static let expandedPanelSize = CGSize(width: 450, height: 450)
    static let expandedPanelHorizontalPadding: CGFloat = 19 * 2
}

extension Notification.Name {
    static let periquitoShouldCollapse = Notification.Name("periquitoShouldCollapse")
}

private let cornerRadiusInsets = (
    opened: (top: CGFloat(19), bottom: CGFloat(24)),
    closed: (top: CGFloat(6), bottom: CGFloat(14))
)

struct NotchContentView: View {
    var stateMachine: PeriquitoStateMachine = .shared
    var panelManager: NotchPanelManager = .shared
    var usageService: ClaudeUsageService = .shared
    @State private var showingPanelSettings = false
    @State private var isMuted = AppSettings.isMuted
    @State private var isActivityCollapsed = false

    private var sessionStore: SessionStore {
        stateMachine.sessionStore
    }

    private var notchSize: CGSize { panelManager.notchSize }
    private var isExpanded: Bool { panelManager.isExpanded }

    private var panelAnimation: Animation {
        isExpanded
            ? .spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.1)
            : .spring(response: 0.35, dampingFraction: 0.9)
    }

    private var sideWidth: CGFloat {
        max(0, notchSize.height - 12) + 24
    }

    private var topCornerRadius: CGFloat {
        isExpanded ? cornerRadiusInsets.opened.top : cornerRadiusInsets.closed.top
    }

    private var bottomCornerRadius: CGFloat {
        isExpanded ? cornerRadiusInsets.opened.bottom : cornerRadiusInsets.closed.bottom
    }

    private var grassHeight: CGFloat {
        let expandedPanelHeight = NotchConstants.expandedPanelSize.height - notchSize.height - 24
        return expandedPanelHeight * 0.3 + notchSize.height
    }

    private var expandedPanelHeight: CGFloat {
        let fullHeight = NotchConstants.expandedPanelSize.height - notchSize.height - 24
        let collapsedHeight: CGFloat = 155
        return isActivityCollapsed ? collapsedHeight : fullHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            notchLayout
        }
        .padding(.horizontal, isExpanded ? cornerRadiusInsets.opened.top : cornerRadiusInsets.closed.bottom)
        .padding(.bottom, isExpanded ? 12 : 0)
        .background {
            ZStack(alignment: .top) {
                Color.black
                GrassIslandView(state: sessionStore.unifiedState)
                    .frame(height: grassHeight, alignment: .bottom)
                    .opacity(isExpanded && !showingPanelSettings ? 1 : 0)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isExpanded && !showingPanelSettings {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isActivityCollapsed.toggle()
                    }
                }) {
                    Image(systemName: isActivityCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .offset(y: grassHeight - 30)
                .padding(.trailing, 30)
            }
        }
        .clipShape(NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: bottomCornerRadius
        ))
        .shadow(
            color: isExpanded ? .black.opacity(0.7) : .clear,
            radius: 6
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(panelAnimation, value: isExpanded)
        .onReceive(NotificationCenter.default.publisher(for: .periquitoShouldCollapse)) { _ in
            panelManager.collapse()
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                showingPanelSettings = false
            }
        }
    }

    @ViewBuilder
    private var notchLayout: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .frame(height: notchSize.height)

                if isExpanded {
                    ExpandedPanelView(
                        sessionStore: sessionStore,
                        showingSettings: $showingPanelSettings,
                        isActivityCollapsed: $isActivityCollapsed
                    )
                    .frame(
                        width: NotchConstants.expandedPanelSize.width - 48,
                        height: expandedPanelHeight
                    )
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .top)
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.45, dampingFraction: 0.8)),
                            removal: .scale(scale: 0.95, anchor: .top)
                                .combined(with: .opacity)
                                .animation(.easeOut(duration: 0.2))
                        )
                    )
                }
            }

            if isExpanded {
                HStack {
                    if showingPanelSettings {
                        backButton
                            .padding(.leading, 15)
                    } else {
                        HStack(spacing: 8) {
                            PanelHeaderButton(
                                sfSymbol: panelManager.isPinned ? "pin.fill" : "pin",
                                action: { panelManager.togglePin() }
                            )
                            PanelHeaderButton(
                                sfSymbol: isMuted ? "bell.slash" : "bell",
                                action: toggleMute
                            )
                        }
                        .padding(.leading, 12)
                    }
                    Spacer()
                    headerButtons
                }
                .padding(.top, 4)
                .padding(.horizontal, 8)
                .frame(width: NotchConstants.expandedPanelSize.width - 48)
            }
        }
    }

    private var headerButtons: some View {
        HStack(spacing: 8) {
            PanelHeaderButton(sfSymbol: "gearshape", action: { showingPanelSettings = true })
            PanelHeaderButton(sfSymbol: "xmark", action: { panelManager.collapse() })
        }
        .padding(.trailing, 8)
    }

    private var backButton: some View {
        Button(action: { showingPanelSettings = false }) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text("Back")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: notchSize.width - cornerRadiusInsets.closed.top)

            headerSprites
                .offset(x: 15, y: -2)
                .frame(width: sideWidth)
                .opacity(isExpanded ? 0 : 1)
                .animation(.none, value: isExpanded)
        }
    }

    @ViewBuilder
    private var headerSprites: some View {
        SessionSpriteView(
            state: sessionStore.unifiedState,
            isSelected: true
        )
    }

    private func toggleMute() {
        AppSettings.toggleMute()
        isMuted = AppSettings.isMuted
    }
}

#Preview {
    NotchContentView()
        .frame(width: 400, height: 200)
}
