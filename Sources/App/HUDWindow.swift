import SwiftUI
import AppKit
import CoreUtils

public enum HUDState {
    case hidden
    case listening(level: Float)
    case processing
}

public class HUDWindow: NSPanel {
    private var hostingView: NSHostingView<HUDContentView>?

    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
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
        let hudContentView = HUDContentView()
        hostingView = NSHostingView(rootView: hudContentView)

        if let hostingView = hostingView {
            contentView = hostingView
        }
    }

    public func show(state: HUDState) {
        centerOnScreen()

        if let hostingView = hostingView {
            hostingView.rootView.updateState(state)
        }

        if !isVisible {
            orderFront(nil)
            alphaValue = 0
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                animator().alphaValue = 1.0
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
        if let hostingView = hostingView {
            hostingView.rootView.updateState(.listening(level: level))
        }
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
    @State private var currentState: HUDState = .hidden

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

            VStack(spacing: 16) {
                switch currentState {
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
        .frame(width: 320, height: 160)
    }

    @ViewBuilder
    private func listeningView(level: Float) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)

            Text("Listening...")
                .font(.headline)
                .foregroundColor(.primary)

            AudioLevelView(level: level)
                .frame(height: 20)

            Text("Press Esc to cancel")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Processing...")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Please wait")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    func updateState(_ state: HUDState) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentState = state
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