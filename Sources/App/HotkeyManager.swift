import Foundation
import AppKit
import Carbon
import CoreUtils

public enum HotkeyMode: String, CaseIterable {
    case pushToTalk = "pushToTalk"
    case toggle = "toggle"

    public var displayName: String {
        switch self {
        case .pushToTalk:
            return L("hotkey.mode.push")
        case .toggle:
            return L("hotkey.mode.toggle")
        }
    }
}

public protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyPressed(mode: HotkeyMode, isKeyDown: Bool)
}

public class HotkeyManager: ObservableObject {
    private let logger = Logger(category: "HotkeyManager")

    public weak var delegate: HotkeyManagerDelegate?

    @Published public var currentMode: HotkeyMode = .toggle
    @Published public var isEnabled: Bool = false

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    // Default hotkey: ⌘⇧V (Command + Shift + V)
    private let defaultKeyCode: UInt32 = 9  // V key
    private let defaultModifiers: UInt32 = UInt32(cmdKey + shiftKey)

    public init() {
        setupEventHandler()
    }

    deinit {
        unregisterHotkey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    public func enableHotkey() {
        guard !isEnabled else { return }

        logger.info("Enabling global hotkey")

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D575350), id: 1) // 'MWSP'

        let status = RegisterEventHotKey(
            defaultKeyCode,
            defaultModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            isEnabled = true
            logger.info("Global hotkey registered successfully")
        } else {
            logger.error("Failed to register global hotkey: \(status)")
        }
    }

    public func disableHotkey() {
        guard isEnabled else { return }

        logger.info("Disabling global hotkey")
        unregisterHotkey()
        isEnabled = false
    }

    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func setupEventHandler() {
        let eventTypes: [EventTypeSpec] = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))
        ]

        let callback: EventHandlerProcPtr = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                OSType(kEventParamDirectObject),
                OSType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return OSStatus(eventNotHandledErr) }

            let eventKind = GetEventKind(theEvent)
            let isKeyDown = eventKind == OSType(kEventHotKeyPressed)

            DispatchQueue.main.async {
                manager.handleHotkeyEvent(isKeyDown: isKeyDown)
            }

            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            2,
            eventTypes,
            selfPtr,
            &eventHandler
        )

        if status != noErr {
            logger.error("Failed to install event handler: \(status)")
        }
    }

    private func handleHotkeyEvent(isKeyDown: Bool) {
        logger.debug("Hotkey event: \(isKeyDown ? "down" : "up"), mode: \(currentMode)")

        switch currentMode {
        case .pushToTalk:
            // In push-to-talk mode, respond to both key down and up
            delegate?.hotkeyPressed(mode: currentMode, isKeyDown: isKeyDown)
        case .toggle:
            // In toggle mode, only respond to key down
            if isKeyDown {
                delegate?.hotkeyPressed(mode: currentMode, isKeyDown: true)
            }
        }
    }
}