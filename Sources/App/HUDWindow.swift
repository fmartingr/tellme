import SwiftUI
import AppKit
import CoreUtils
import CoreSettings

public enum HUDState {
    case hidden
    case listening(level: Float)
    case processing
}

public class HUDWindow: NSPanel, ObservableObject {
    private var hostingView: NSHostingView<HUDContentView>?
    private let settings: CoreSettings.Settings
    @Published var hudState: HUDState = .hidden

    public init(settings: CoreSettings.Settings) {
        self.settings = settings

        let baseWidth: CGFloat = 320
        let baseHeight: CGFloat = 160
        let scaledWidth = baseWidth * settings.hudSize
        let scaledHeight = baseHeight * settings.hudSize

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        setupContentView()
    }

    private func setupWindow() {
        level = .floating
        isOpaque = false
        backgroundColor = NSColor.clear
        hasShadow = true
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func setupContentView() {
        let hudContentView = HUDContentView(settings: settings, hudWindow: self)
        hostingView = NSHostingView(rootView: hudContentView)

        if let hostingView = hostingView {
            contentView = hostingView
        }
    }

    public func show(state: HUDState) {
        centerOnScreen()

        // Update the published state
        hudState = state
        print("HUD showing with state: \(state)")

        if !isVisible {
            orderFront(nil)
            alphaValue = 0
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                animator().alphaValue = settings.hudOpacity
            })
        }
    }

    public func hide() {
        guard isVisible else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }

    public func updateLevel(_ level: Float) {
        hudState = .listening(level: level)
    }

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let windowSize = frame.size

        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.midY - windowSize.height / 2

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    override public func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            NotificationCenter.default.post(name: .hudEscapePressed, object: nil)
            return
        }
        super.keyDown(with: event)
    }

    override public var canBecomeKey: Bool {
        return true  // Allow the window to receive key events
    }
}

extension Notification.Name {
    static let hudEscapePressed = Notification.Name("hudEscapePressed")
}

struct HUDContentView: View {
    @ObservedObject var settings: CoreSettings.Settings
    @ObservedObject var hudWindow: HUDWindow

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

            VStack(spacing: 16) {
                switch hudWindow.hudState {
                case .hidden:
                    EmptyView()

                case .listening(let level):
                    listeningView(level: level)

                case .processing:
                    processingView
                }
            }
            .padding(24)
        }
        .frame(width: 320 * settings.hudSize, height: 160 * settings.hudSize)
        .scaleEffect(settings.hudSize)
        .onAppear {
            print("HUD Content View appeared with state: \(hudWindow.hudState)")
        }
    }

    @ViewBuilder
    private func listeningView(level: Float) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            Text(L("hud.listening"))
                .font(.headline)
                .foregroundColor(.primary)

            AudioLevelView(level: level)
                .frame(height: 20)

            Text(L("hud.cancel"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text(L("hud.processing"))
                .font(.headline)
                .foregroundColor(.primary)

            Text(L("hud.please_wait"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

}

struct AudioLevelView: View {
    let level: Float
    private let barCount = 20

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 12, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.1), value: level)
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) / Float(barCount - 1)
        return level > threshold ? 20 : 4
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Float(index) / Float(barCount - 1)

        if level > threshold {
            if threshold < 0.6 {
                return .green
            } else if threshold < 0.8 {
                return .orange
            } else {
                return .red
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
}