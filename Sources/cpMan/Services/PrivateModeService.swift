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
            settings.privateModeEndEpoch = 0   // indefinite — no auto-off
            return
        }

        let end = Date().addingTimeInterval(Double(minutes) * 60)
        settings.privateModeEndEpoch = end.timeIntervalSinceReferenceDate
        scheduleAutoOff(at: end)
    }

    /// Disable private mode and cancel any running timer.
    func disable() {
        cancelTimer()
        let settings = AppSettings.shared
        settings.isPrivateModeEnabled = false
        settings.privateModeEndEpoch  = 0
    }

    /// Re-arms (or expires) a timed Private Mode session after a relaunch. The auto-off
    /// timer lives only in memory, so without this a "2 hours" session would silently
    /// keep recording paused forever, or be dropped entirely. Call once on launch.
    func restoreOnLaunch() {
        let settings = AppSettings.shared
        guard settings.isPrivateModeEnabled else { return }
        let epoch = settings.privateModeEndEpoch
        guard epoch > 0 else { return }   // indefinite session — stay paused, no timer

        let end = Date(timeIntervalSinceReferenceDate: epoch)
        if Date() >= end {
            disable()   // the window already elapsed while the app was not running
        } else {
            scheduleAutoOff(at: end)
        }
    }

    // MARK: - Private

    private func scheduleAutoOff(at end: Date) {
        let seconds = end.timeIntervalSinceNow
        guard seconds > 0 else { disable(); return }
        timerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.disable()
            }
        }
    }

    private func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}
