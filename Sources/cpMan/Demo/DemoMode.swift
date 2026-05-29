import Foundation

/// App Review demo mode: loads fictional clipboard samples on demand.
///
/// Production users start with an empty history. Reviewers enable demo content via:
///   • launch argument `-CPManDemoMode`
///   • environment variable `CPMAN_DEMO_MODE=1`
///   • menu bar → Load Demo Content (fallback)
enum DemoMode {
    static let launchArgument = "-CPManDemoMode"
    static let environmentKey = "CPMAN_DEMO_MODE"

    static let activeUserDefaultsKey = "cpMan.demoModeEnabled"

    /// True when demo content is loaded and the UI should show the demo badge.
    static var isActive: Bool {
        UserDefaults.standard.bool(forKey: activeUserDefaultsKey)
    }

    static var isRequestedViaLaunchEnvironment: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
            || ProcessInfo.processInfo.environment[environmentKey] == "1"
    }

    static func activate() {
        UserDefaults.standard.set(true, forKey: activeUserDefaultsKey)
    }

    static func deactivate() {
        UserDefaults.standard.set(false, forKey: activeUserDefaultsKey)
    }

    /// Seeds demo clips only when a review launch flag or env var is present.
    @MainActor
    static func applyOnLaunch(to store: HistoryStore) {
        guard isRequestedViaLaunchEnvironment else { return }
        store.loadDemoContent(replacingExisting: true)
        activate()
    }

    /// Menu action: always reloads the canonical sample set.
    @MainActor
    static func reloadDemoContent(in store: HistoryStore) {
        store.loadDemoContent(replacingExisting: true)
        activate()
    }

    /// Clears history and turns off the demo badge.
    @MainActor
    static func clearDemoContent(in store: HistoryStore) {
        store.replaceAll(with: [])
        deactivate()
    }
}
