import SwiftUI

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

        window.title = NSLocalizedString("preview.title", comment: "Preview Transcription")
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
                Text(NSLocalizedString("preview.title", comment: "Preview Transcription"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(NSLocalizedString("preview.description", comment: "Review and edit the transcribed text before insertion."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Text Editor
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("preview.transcribed_text", comment: "Transcribed Text:"))
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
                Text(String(format: NSLocalizedString("preview.character_count", comment: "%d characters"), text.count))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Buttons
                HStack(spacing: 12) {
                    Button(NSLocalizedString("general.cancel", comment: "Cancel")) {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)

                    Button(NSLocalizedString("preview.insert", comment: "Insert")) {
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