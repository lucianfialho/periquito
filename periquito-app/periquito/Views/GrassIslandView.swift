import SwiftUI

private enum SpriteLayout {
    static let size: CGFloat = 64
}

// MARK: - Visual layer (placed in .background, no interaction)

struct GrassIslandView: View {
    let state: PeriquitoState

    private let patchWidth: CGFloat = 80

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                HStack(spacing: 0) {
                    ForEach(0..<patchCount(for: geometry.size.width), id: \.self) { _ in
                        Image("GrassIsland")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: patchWidth, height: geometry.size.height)
                            .clipped()
                    }
                }
                .frame(width: geometry.size.width, alignment: .leading)
                .drawingGroup()

                GrassSpriteView(state: state, totalWidth: geometry.size.width)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private func patchCount(for width: CGFloat) -> Int {
        Int(ceil(width / patchWidth)) + 1
    }
}

// MARK: - Single centered parrot

private struct GrassSpriteView: View {
    let state: PeriquitoState
    let totalWidth: CGFloat

    @State private var walkOffset: CGFloat = 0
    @State private var walkDirection: CGFloat = 1
    @State private var walkTimer: Task<Void, Never>?
    @State private var isWalking: Bool = false

    private let swayDuration: Double = 2.0
    private var bobAmplitude: CGFloat {
        guard state.bobAmplitude > 0 else { return 0 }
        return state.task == .working ? 0.5 : 0.3
    }
    private let glowColor = Color(red: 0.4, green: 0.7, blue: 1.0)

    private var swayAmplitude: Double {
        (state.task == .sleeping || state.task == .compacting) ? 0 : state.swayAmplitude
    }

    private var isAnimatingMotion: Bool {
        bobAmplitude > 0 || swayAmplitude > 0 || state.emotion == .sob || state.canWalk
    }

    private var bobDuration: Double {
        state.task == .working ? 1.0 : state.bobDuration
    }

    private func swayDegrees(at date: Date) -> Double {
        guard swayAmplitude > 0 else { return 0 }
        let t = date.timeIntervalSinceReferenceDate
        let phase = (t / swayDuration).truncatingRemainder(dividingBy: 1.0)
        return sin(phase * .pi * 2) * swayAmplitude
    }

    private static let sobTrembleAmplitude: CGFloat = 0.3

    private var walkRange: CGFloat {
        totalWidth * 0.10
    }

    /// Pixels per second — matches leg animation at 10fps × 64px sprite
    private let walkSpeed: CGFloat = 22

    /// When walking, override sprite to the walk animation
    private var activeSpriteSheet: String {
        isWalking ? "walk" : state.spriteSheetName
    }

    private var activeFrameCount: Int {
        isWalking ? 16 : state.frameCount
    }

    private var activeFPS: Double {
        isWalking ? 10.0 : state.animationFPS
    }

    /// walk.png faces LEFT by default; other sprites face RIGHT.
    /// Flip walk sprite when going right, flip others when going left.
    private var spriteScaleX: CGFloat {
        isWalking ? (walkDirection >= 0 ? -1 : 1) : (walkDirection >= 0 ? 1 : -1)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isAnimatingMotion)) { timeline in
            VStack(spacing: 0) {
                SpriteSheetView(
                    spriteSheet: activeSpriteSheet,
                    frameCount: activeFrameCount,
                    columns: state.columns,
                    fps: activeFPS,
                    isAnimating: true
                )
                .frame(width: SpriteLayout.size, height: SpriteLayout.size)
                .scaleEffect(x: spriteScaleX, y: 1, anchor: .center)
                .overlay(alignment: .bottomTrailing) {
                    Text(LevelManager.shared.level.emoji)
                        .font(.system(size: 12))
                        .shadow(color: .black, radius: 1, x: 0, y: 0.5)
                        .offset(x: 4, y: 4)
                        .scaleEffect(x: spriteScaleX, y: 1, anchor: .center)
                }
                .rotationEffect(.degrees(swayDegrees(at: timeline.date)), anchor: .bottom)

                // Shadow ellipse
                Ellipse()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 24, height: 6)
                    .blur(radius: 1.5)
                    .offset(y: -13)
            }
            .offset(
                x: walkOffset + trembleOffset(at: timeline.date, amplitude: state.emotion == .sob ? Self.sobTrembleAmplitude : 0),
                y: -4 + bobOffset(at: timeline.date, duration: bobDuration, amplitude: bobAmplitude)
            )
        }
        .onAppear { startWalking() }
        .onDisappear { walkTimer?.cancel() }
        .onChange(of: state.canWalk) { _, canWalk in
            if canWalk {
                startWalking()
            } else {
                walkTimer?.cancel()
                isWalking = false
            }
        }
    }

    private func startWalking() {
        walkTimer?.cancel()
        guard state.canWalk else {
            isWalking = false
            return
        }

        walkTimer = Task {
            while !Task.isCancelled {
                let range = state.walkFrequencyRange
                let delay = Double.random(in: range)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, state.canWalk else { break }

                let target = CGFloat.random(in: -walkRange...walkRange)
                let newDirection: CGFloat = target > walkOffset ? 1 : -1
                let distance = abs(target - walkOffset)
                let walkDuration = max(0.5, Double(distance / walkSpeed))

                await MainActor.run {
                    isWalking = true
                    if newDirection != walkDirection {
                        walkDirection = newDirection
                    }
                    withAnimation(.easeInOut(duration: walkDuration)) {
                        walkOffset = target
                    }
                }

                // Stop walk animation after movement completes
                try? await Task.sleep(for: .seconds(walkDuration))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    isWalking = false
                }
            }
        }
    }
}
