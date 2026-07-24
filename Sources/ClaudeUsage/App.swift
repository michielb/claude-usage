import SwiftUI

@MainActor
let sharedService = UsageService()

@MainActor
let sharedHUD = HUDController(service: sharedService)

@MainActor
let sharedSettings = AppSettings()

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            DetailView(service: sharedService, hud: sharedHUD, settings: sharedSettings)
        } label: {
            MenuBarView(service: sharedService, settings: sharedSettings)
        }
        .menuBarExtraStyle(.window)

        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var onboardingWindow: NSWindow?
    private var stateObservation: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Briefly activate the app so the MenuBarExtra registers reliably,
        // then switch back to accessory mode to hide from Dock/Cmd-Tab.
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
            // Show the HUD only after the initial launch layout has settled.
            // Creating and animating the panel synchronously inside the first
            // display cycle races with AppKit's constraint/layout pass and can
            // throw an uncaught exception during commit (crash on launch).
            sharedHUD.forceShow()
        }
        observeServiceState()
    }

    private func observeServiceState() {
        scheduleObservation()
    }

    private func scheduleObservation() {
        withObservationTracking {
            _ = sharedService.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleStateChange()
                self?.scheduleObservation()
            }
        }
    }

    private func handleStateChange() {
        switch sharedService.state {
        case .needsSignIn, .authExpired:
            showOnboarding()
        case .ready:
            dismissOnboarding()
        case .loading, .noSession, .reconnecting:
            break
        }
    }

    private func showOnboarding() {
        guard onboardingWindow == nil else { return }

        let hosting = NSHostingController(rootView: OnboardingView(service: sharedService))
        let window = NSWindow(contentViewController: hosting)
        // Freeze the window size once AppKit has sized it to the content. Left
        // dynamic, the hosting view drives an animated window resize
        // (NSHostingView.updateAnimatedWindowSize) that can re-enter AppKit's
        // constraint pass mid-display-cycle and throw an uncaught exception —
        // the recurring launch crash (SIGABRT/SIGTRAP in the display cycle).
        // Onboarding's layout is effectively fixed, so freezing costs nothing.
        hosting.sizingOptions = []
        window.styleMask = [.titled, .closable]
        window.title = "Claude Usage Setup"
        window.level = .floating
        window.center()
        onboardingWindow = window

        // Present on the next runloop turn so the window is never ordered in
        // from inside an in-progress display/commit cycle.
        DispatchQueue.main.async {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func dismissOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }
}
