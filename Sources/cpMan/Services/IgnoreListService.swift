import AppKit

/// Manages the user-configured list of apps whose clipboard activity is ignored.
/// Rules are stored as bundle identifiers (stable, unique per app).
/// @MainActor because all reads/writes go through AppSettings.shared (also @MainActor).
@MainActor
final class IgnoreListService {
    static let shared = IgnoreListService()

    private init() {}

    func isIgnored(bundleId: String) -> Bool {
        AppSettings.shared.ignoredBundleIds.contains(bundleId)
    }

    func add(bundleId: String) {
        var ids = AppSettings.shared.ignoredBundleIds
        guard !ids.contains(bundleId) else { return }
        ids.append(bundleId)
        AppSettings.shared.ignoredBundleIds = ids
    }

    func remove(bundleId: String) {
        AppSettings.shared.ignoredBundleIds.removeAll { $0 == bundleId }
    }

    /// Returns running apps that are regular UI apps (excludes daemons, agents).
    func runningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
