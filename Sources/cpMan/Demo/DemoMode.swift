import Foundation

/// App Review demo mode: loads fictional clipboard samples when launched with
/// `-CPManDemoMode` or `CPMAN_DEMO_MODE=1`. Not exposed in the customer UI.
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
