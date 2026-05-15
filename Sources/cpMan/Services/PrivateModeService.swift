import Foundation

/// Manages enabling / disabling Private Mode, including optional timed auto-off.
@MainActor
final class PrivateModeService {
    static let shared = PrivateModeService()
    private init() {}

    /// Duration options shown in the menu.
    struct DurationOption: Identifiable {
        let id: Int          // minutes; 0 = indefinite
        let label: String
    }

    static let durations: [DurationOption] = [
        DurationOption(id: 15,  label: "15 Minutes"),
        DurationOption(id: 30,  label: "30 Minutes"),
        DurationOption(id: 60,  label: "1 Hour"),
        DurationOption(id: 120, label: "2 Hours"),
        DurationOption(id: 0,   label: "Until I Turn It Off"),
    ]

    private var timerTask: Task<Void, Never>?

    // MARK: - Public interface

    /// Enable private mode for `minutes` (0 = indefinite). Saves the choice as the new default.
    func enable(minutes: Int) {
        let settings = AppSettings.shared
        settings.isPrivateModeEnabled           = true
        settings.lastPrivateModeDurationMinutes = minutes

        cancelTimer()
        guard minutes > 0 else {
            settings.privateModeExpiresAt = nil
            return
        }

        let expiresAt = Date().addingTimeInterval(Double(minutes) * 60)
        settings.privateModeExpiresAt = expiresAt
        scheduleDisable(after: expiresAt.timeIntervalSinceNow)
    }

    /// Recreates the in-memory timer after relaunch. If the stored expiration
    /// already passed while the app was closed, recording resumes immediately.
    func restorePersistedState(now: Date = Date()) {
        let settings = AppSettings.shared
        cancelTimer()

        guard settings.isPrivateModeEnabled else {
            settings.privateModeExpiresAt = nil
            return
        }

        guard let expiresAt = settings.privateModeExpiresAt else { return }
        let remaining = expiresAt.timeIntervalSince(now)
        guard remaining > 0 else {
            disable()
            return
        }

        scheduleDisable(after: remaining)
    }

    private func scheduleDisable(after seconds: TimeInterval) {
        timerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.disable()
            }
        }
    }

    /// Disable private mode and cancel any running timer.
    func disable() {
        cancelTimer()
        let settings = AppSettings.shared
        settings.isPrivateModeEnabled = false
        settings.privateModeExpiresAt = nil
    }

    // MARK: - Private

    private func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
