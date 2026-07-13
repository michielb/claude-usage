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
        }
        sharedHUD.forceShow()
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

        let window = NSWindow(
            contentViewController: NSHostingController(rootView: OnboardingView(service: sharedService))
        )
        window.styleMask = [.titled, .closable]
        window.title = "Claude Usage Setup"
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func dismissOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }
}
