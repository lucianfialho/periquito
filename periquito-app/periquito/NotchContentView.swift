import SwiftUI

enum NotchConstants {
    static let expandedPanelSize = CGSize(width: 450, height: 450)
    static let expandedPanelHorizontalPadding: CGFloat = 19 * 2
}

private let cornerRadiusInsets = (
    opened: (top: CGFloat(19), bottom: CGFloat(24)),
    closed: (top: CGFloat(6), bottom: CGFloat(14))
)

@MainActor
struct NotchContentView: View {
    @State private var viewModel: NotchViewModel
    @State private var expandedPanelViewModel: ExpandedPanelViewModel

    init(viewModel: NotchViewModel? = nil) {
        let viewModel = viewModel ?? NotchViewModel()
        _viewModel = State(initialValue: viewModel)
        _expandedPanelViewModel = State(
            initialValue: ExpandedPanelViewModel(sessionStore: viewModel.sessionStore)
        )
    }

    var body: some View {
        @Bindable var bindableViewModel = viewModel

        VStack(spacing: 0) {
            notchLayout(
                showingSettings: $bindableViewModel.showingPanelSettings,
                isActivityCollapsed: $bindableViewModel.isActivityCollapsed
            )
        }
        .padding(.horizontal, viewModel.isExpanded ? cornerRadiusInsets.opened.top : cornerRadiusInsets.closed.bottom)
        .padding(.bottom, viewModel.isExpanded ? 12 : 0)
        .background {
            ZStack(alignment: .top) {
                Color.black
                GrassIslandView(state: viewModel.sessionStore.unifiedState)
                    .frame(height: viewModel.grassHeight, alignment: .bottom)
                    .opacity(viewModel.isExpanded && !viewModel.showingPanelSettings ? 1 : 0)
            }
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.isExpanded && !viewModel.showingPanelSettings {
                Button(action: viewModel.toggleActivityCollapse) {
                    Image(systemName: viewModel.isActivityCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .offset(y: viewModel.grassHeight - 30)
                .padding(.trailing, 30)
            }
        }
        .clipShape(
            NotchShape(
                topCornerRadius: viewModel.topCornerRadius,
                bottomCornerRadius: viewModel.bottomCornerRadius
            )
        )
        .shadow(color: viewModel.isExpanded ? .black.opacity(0.7) : .clear, radius: 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(viewModel.panelAnimation, value: viewModel.isExpanded)
        .onReceive(NotificationCenter.default.publisher(for: .periquitoShouldCollapse)) { _ in
            viewModel.collapsePanel()
        }
        .onChange(of: viewModel.isExpanded) { _, expanded in
            viewModel.handleExpansionChange(expanded)
        }
    }

    @ViewBuilder
    private func notchLayout(
        showingSettings: Binding<Bool>,
        isActivityCollapsed: Binding<Bool>
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                    .frame(height: viewModel.notchSize.height)

                if viewModel.isExpanded {
                    ExpandedPanelView(
                        viewModel: expandedPanelViewModel,
                        showingSettings: showingSettings,
                        isActivityCollapsed: isActivityCollapsed
                    )
                    .frame(
                        width: NotchConstants.expandedPanelSize.width - 48,
                        height: viewModel.expandedPanelHeight
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

            if viewModel.isExpanded {
                HStack {
                    if viewModel.showingPanelSettings {
                        backButton
                            .padding(.leading, 15)
                    } else {
                        HStack(spacing: 8) {
                            PanelHeaderButton(
                                sfSymbol: viewModel.panelManager.isPinned ? "pin.fill" : "pin",
                                action: viewModel.togglePin
                            )
                            PanelHeaderButton(
                                sfSymbol: viewModel.isMuted ? "bell.slash" : "bell",
                                action: viewModel.toggleMute
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
            PanelHeaderButton(sfSymbol: "gearshape", action: viewModel.showSettings)
            PanelHeaderButton(sfSymbol: "xmark", action: viewModel.collapsePanel)
        }
        .padding(.trailing, 8)
    }

    private var backButton: some View {
        Button(action: viewModel.hideSettings) {
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

    private var headerRow: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: viewModel.notchSize.width - cornerRadiusInsets.closed.top)

            SessionSpriteView(
                state: viewModel.sessionStore.unifiedState,
                isSelected: true
            )
            .offset(x: 15, y: -2)
            .frame(width: viewModel.sideWidth)
            .opacity(viewModel.isExpanded ? 0 : 1)
            .animation(.none, value: viewModel.isExpanded)
        }
    }
}

#Preview {
    NotchContentView()
        .frame(width: 400, height: 200)
}
