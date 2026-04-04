import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {
    private var notchPanel: NotchPanel?
    private let panelManager: NotchPanelManager
    private let screenSelector: ScreenSelector
    private let windowHeight: CGFloat = 500

    init(
        panelManager: NotchPanelManager? = nil,
        screenSelector: ScreenSelector? = nil
    ) {
        self.panelManager = panelManager ?? .shared
        self.screenSelector = screenSelector ?? .shared
    }

    func setupWindow() {
        screenSelector.refreshScreens()

        guard let screen = screenSelector.selectedScreen else {
            return
        }

        panelManager.updateGeometry(for: screen)

        let panel = NotchPanel(frame: windowFrame(for: screen))
        let contentView = NotchContentView()
        let hostingView = NSHostingView(rootView: contentView)

        let hitTestView = NotchHitTestView()
        hitTestView.panelManager = panelManager
        hitTestView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: hitTestView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: hitTestView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: hitTestView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: hitTestView.trailingAnchor),
        ])

        panel.contentView = hitTestView
        panel.orderFrontRegardless()
        notchPanel = panel
    }

    func repositionWindow() {
        guard let panel = notchPanel else {
            return
        }

        screenSelector.refreshScreens()

        guard let screen = screenSelector.selectedScreen else {
            return
        }

        panelManager.updateGeometry(for: screen)
        panel.setFrame(windowFrame(for: screen), display: true)
    }

    private func windowFrame(for screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame

        return NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )
    }
}
