import AppKit

@MainActor
@Observable
final class AppSettings {
    var isCompactMode: Bool {
        didSet {
            UserDefaults.standard.set(isCompactMode, forKey: "compactMode")
        }
    }

    private var screenObserver: NSObjectProtocol?

    init() {
        let stored = UserDefaults.standard.bool(forKey: "compactMode")
        self.isCompactMode = stored

        // Auto-detect small screens
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkScreenSize()
            }
        }

        // Initial check
        checkScreenSize()
    }

    private func checkScreenSize() {
        guard let screen = NSScreen.main else { return }
        // On screens narrower than 1200pt, the full progress bars likely won't fit
        // alongside other menu bar items. Auto-enable compact mode.
        let narrow = screen.frame.width < 1200
        if narrow && !isCompactMode {
            isCompactMode = true
        }
    }
}
