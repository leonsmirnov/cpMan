import Foundation

/// App Review demo mode: loads fictional clipboard samples (text + images) when
/// launched with `-CPManDemoMode` or `CPMAN_DEMO_MODE=1`. Never exposed in the
/// customer-facing UI — it only activates from a launch argument / environment
/// variable, so normal users never see seeded content.
enum DemoMode {
    static let launchArgument = "-CPManDemoMode"
    static let environmentKey = "CPMAN_DEMO_MODE"

    private static let activeUserDefaultsKey = "cpMan.demoModeEnabled"

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
}
