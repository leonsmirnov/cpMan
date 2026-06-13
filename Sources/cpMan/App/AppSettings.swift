import Foundation
import Combine

/// Central settings store backed by UserDefaults.
/// All properties publish changes so SwiftUI views update automatically.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - History
    @Published var historyCountLimit: Int          { didSet { save(historyCountLimit, key: .historyCountLimit) } }
    @Published var historySizeLimitEnabled: Bool   { didSet { save(historySizeLimitEnabled, key: .historySizeLimitEnabled) } }
    @Published var historySizeLimitMB: Int         { didSet { save(historySizeLimitMB, key: .historySizeLimitMB) } }
    @Published var historyAgeLimitEnabled: Bool    { didSet { save(historyAgeLimitEnabled, key: .historyAgeLimitEnabled) } }
    @Published var historyAgeLimitDays: Int        { didSet { save(historyAgeLimitDays, key: .historyAgeLimitDays) } }

    // MARK: - Behaviour
    @Published var autoPasteEnabled: Bool          { didSet { save(autoPasteEnabled, key: .autoPasteEnabled) } }
    @Published var isPrivateModeEnabled: Bool       { didSet { save(isPrivateModeEnabled, key: .isPrivateModeEnabled) } }
    /// Last chosen private mode duration in minutes. 0 = indefinite.
    @Published var lastPrivateModeDurationMinutes: Int { didSet { save(lastPrivateModeDurationMinutes, key: .lastPrivateModeDurationMinutes) } }
    /// Absolute end time of a *timed* Private Mode session, as
    /// `Date.timeIntervalSinceReferenceDate`. 0 = no timed session (off or indefinite).
    /// Persisted so a timed session can be re-armed (or expired) after a relaunch
    /// instead of being silently dropped — the in-memory timer does not survive quit.
    @Published var privateModeEndEpoch: Double { didSet { save(privateModeEndEpoch, key: .privateModeEndEpoch) } }

    // MARK: - Images
    // Note: image metadata (EXIF/GPS/XMP) is ALWAYS stripped during the PNG
    // re-encode in ImageProcessor — there is intentionally no toggle for it.
    @Published var ocrEnabled: Bool                { didSet { save(ocrEnabled, key: .ocrEnabled) } }
    @Published var imageMaxDimensionEnabled: Bool  { didSet { save(imageMaxDimensionEnabled, key: .imageMaxDimensionEnabled) } }
    @Published var imageMaxDimension: Int          { didSet { save(imageMaxDimension, key: .imageMaxDimension) } }
    @Published var imageSizeLimitEnabled: Bool     { didSet { save(imageSizeLimitEnabled, key: .imageSizeLimitEnabled) } }
    @Published var imageSizeLimitMB: Int           { didSet { save(imageSizeLimitMB, key: .imageSizeLimitMB) } }

    // MARK: - Ignore list (stored as JSON-encoded [String])
    @Published var ignoredBundleIds: [String] {
        didSet {
            let data = (try? JSONEncoder().encode(ignoredBundleIds)) ?? Data()
            UserDefaults.standard.set(data, forKey: Key.ignoredBundleIds.rawValue)
        }
    }

    // MARK: - Init
    private init() {
        let d = UserDefaults.standard
        historyCountLimit         = d.intOrDefault(key: .historyCountLimit, default: 200)
        historySizeLimitEnabled   = d.bool(forKey: Key.historySizeLimitEnabled.rawValue)
        historySizeLimitMB        = d.intOrDefault(key: .historySizeLimitMB, default: 500)
        historyAgeLimitEnabled    = d.bool(forKey: Key.historyAgeLimitEnabled.rawValue)
        historyAgeLimitDays       = d.intOrDefault(key: .historyAgeLimitDays, default: 30)
        autoPasteEnabled                  = d.boolOrDefault(key: .autoPasteEnabled, default: true)
        isPrivateModeEnabled              = d.bool(forKey: Key.isPrivateModeEnabled.rawValue)
        lastPrivateModeDurationMinutes    = d.intOrDefault(key: .lastPrivateModeDurationMinutes, default: 0)
        privateModeEndEpoch               = d.double(forKey: Key.privateModeEndEpoch.rawValue)
        ocrEnabled                = d.boolOrDefault(key: .ocrEnabled, default: true)
        imageMaxDimensionEnabled  = d.bool(forKey: Key.imageMaxDimensionEnabled.rawValue)
        imageMaxDimension         = d.intOrDefault(key: .imageMaxDimension, default: 2048)
        imageSizeLimitEnabled     = d.bool(forKey: Key.imageSizeLimitEnabled.rawValue)
        imageSizeLimitMB          = d.intOrDefault(key: .imageSizeLimitMB, default: 5)

        if let data = d.data(forKey: Key.ignoredBundleIds.rawValue),
           let ids  = try? JSONDecoder().decode([String].self, from: data) {
            ignoredBundleIds = ids
        } else {
            ignoredBundleIds = []
        }
    }

    // MARK: - Helpers
    private func save(_ value: some Any, key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    fileprivate enum Key: String {
        case historyCountLimit, historySizeLimitEnabled, historySizeLimitMB
        case historyAgeLimitEnabled, historyAgeLimitDays
        case autoPasteEnabled, isPrivateModeEnabled, lastPrivateModeDurationMinutes
        case privateModeEndEpoch
        case ocrEnabled
        case imageMaxDimensionEnabled, imageMaxDimension
        case imageSizeLimitEnabled, imageSizeLimitMB
        case ignoredBundleIds
    }
}

// MARK: - UserDefaults convenience
private extension UserDefaults {
    // C2 FIX: use object(forKey:) to distinguish "key absent" (→ use default)
    // from "explicitly saved 0" (→ honour 0 as "no limit").
    func intOrDefault(key: AppSettings.Key, default fallback: Int) -> Int {
        (object(forKey: key.rawValue) as? Int) ?? fallback
    }
    func boolOrDefault(key: AppSettings.Key, default fallback: Bool) -> Bool {
        object(forKey: key.rawValue) as? Bool ?? fallback
    }
}

