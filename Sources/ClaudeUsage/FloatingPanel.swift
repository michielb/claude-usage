import AppKit
import SwiftUI

@MainActor
@Observable
final class HUDController {
    private var panel: FloatingPanel?
    private let service: UsageService

    var isVisible: Bool {
        didSet {
            if isVisible {
                showPanel()
            } else {
                panel?.orderOut(nil)
            }
            UserDefaults.standard.set(isVisible, forKey: "hudVisible")
        }
    }

    init(service: UsageService) {
        self.service = service
        // Default to visible on first launch (when key hasn't been set yet)
        if UserDefaults.standard.object(forKey: "hudVisible") == nil {
            self.isVisible = true
        } else {
            self.isVisible = UserDefaults.standard.bool(forKey: "hudVisible")
        }
    }

    func toggle() {
        isVisible.toggle()
    }

    func restoreIfNeeded() {
        if isVisible {
            showPanel()
        }
    }

    /// Force-show the HUD (e.g. compact mode)
    func forceShow() {
        isVisible = true
        showPanel()
    }

    private func showPanel() {
        if panel == nil {
            panel = FloatingPanel(service: service)
            panel?.onClose = { [weak self] in
                self?.isVisible = false
            }
        }
        panel?.orderFront(nil)
    }
}

final class FloatingPanel: NSPanel {
    var onClose: (() -> Void)?

    init(service: UsageService) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 196, height: 270),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        title = "Claude Usage"
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow

        contentViewController = NSHostingController(rootView: DetailView(service: service))

        // Position top-right
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - frame.width - 20
            let y = screen.visibleFrame.maxY - frame.height - 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    override func close() {
        onClose?()
        orderOut(nil)
    }
}
