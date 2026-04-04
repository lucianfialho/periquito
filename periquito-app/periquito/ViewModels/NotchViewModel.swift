import SwiftUI

private let notchCornerRadiusInsets = (
    opened: (top: CGFloat(19), bottom: CGFloat(24)),
    closed: (top: CGFloat(6), bottom: CGFloat(14))
)

@MainActor
@Observable
final class NotchViewModel {
    let stateMachine: PeriquitoStateMachine
    let panelManager: NotchPanelManager
    let usageService: ClaudeUsageService

    var showingPanelSettings = false
    var isMuted = AppSettings.isMuted
    var isActivityCollapsed = false

    init(
        stateMachine: PeriquitoStateMachine? = nil,
        panelManager: NotchPanelManager? = nil,
        usageService: ClaudeUsageService? = nil
    ) {
        self.stateMachine = stateMachine ?? .shared
        self.panelManager = panelManager ?? .shared
        self.usageService = usageService ?? .shared
    }

    var sessionStore: SessionStore {
        stateMachine.sessionStore
    }

    var notchSize: CGSize {
        panelManager.notchSize
    }

    var isExpanded: Bool {
        panelManager.isExpanded
    }

    var panelAnimation: Animation {
        isExpanded
            ? .spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.1)
            : .spring(response: 0.35, dampingFraction: 0.9)
    }

    var sideWidth: CGFloat {
        max(0, notchSize.height - 12) + 24
    }

    var topCornerRadius: CGFloat {
        isExpanded ? notchCornerRadiusInsets.opened.top : notchCornerRadiusInsets.closed.top
    }

    var bottomCornerRadius: CGFloat {
        isExpanded ? notchCornerRadiusInsets.opened.bottom : notchCornerRadiusInsets.closed.bottom
    }

    var grassHeight: CGFloat {
        let panelHeight = NotchConstants.expandedPanelSize.height - notchSize.height - 24
        return panelHeight * 0.3 + notchSize.height
    }

    var expandedPanelHeight: CGFloat {
        let fullHeight = NotchConstants.expandedPanelSize.height - notchSize.height - 24
        let collapsedHeight: CGFloat = 155
        return isActivityCollapsed ? collapsedHeight : fullHeight
    }

    func toggleActivityCollapse() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isActivityCollapsed.toggle()
        }
    }

    func togglePin() {
        panelManager.togglePin()
    }

    func showSettings() {
        showingPanelSettings = true
    }

    func hideSettings() {
        showingPanelSettings = false
    }

    func collapsePanel() {
        panelManager.collapse()
    }

    func handleExpansionChange(_ expanded: Bool) {
        if !expanded {
            showingPanelSettings = false
        }
    }

    func toggleMute() {
        AppSettings.toggleMute()
        isMuted = AppSettings.isMuted
    }
}
