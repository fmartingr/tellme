import SwiftUI
import CoreUtils

class PreviewDialogController: NSWindowController {
    private var previewView: PreviewDialogView?

    init(text: String, onInsert: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        window.title = L("preview.title")
        window.center()
        window.level = .floating

        previewView = PreviewDialogView(
            text: text,
            onInsert: { [weak self] editedText in
                onInsert(editedText)
                self?.close()
            },
            onCancel: { [weak self] in
                onCancel()
                self?.close()
            }
        )

        window.contentView = NSHostingView(rootView: previewView!)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PreviewDialogView: View {
    @State private var text: String
    let onInsert: (String) -> Void
    let onCancel: () -> Void

    @FocusState private var isTextFocused: Bool

    init(text: String, onInsert: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self._text = State(initialValue: text)
        self.onInsert = onInsert
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(L("preview.title"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(L("preview.description"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Text Editor
            VStack(alignment: .leading, spacing: 8) {
                Text(L("preview.transcribed_text"))
                    .font(.headline)

                ScrollView {
                    TextEditor(text: $text)
                        .focused($isTextFocused)
                        .font(.body)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .frame(minHeight: 120)
            }

            // Actions
            HStack {
                // Character count
                Text(String(format: L("preview.character_count"), text.count))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Buttons
                HStack(spacing: 12) {
                    Button(L("general.cancel")) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)

                    Button(L("preview.insert")) {
                        onInsert(text)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(20)
        .frame(width: 500, height: 300)
        .onAppear {
            isTextFocused = true
        }
    }
}