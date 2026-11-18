import Foundation
import os

@MainActor
@Observable
final class SettingsStore {
    static let defaultsKey = "BTAudioSwitch.settings.v1"
    private static let logger = Logger(subsystem: BundleInfo.subsystem, category: "settings")

    private let defaults: any PreferenceStore

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persist()
            onChange?()
        }
    }

    var onChange: (() -> Void)?

    init(defaults: any PreferenceStore) {
        self.defaults = defaults
        settings = Self.load(from: defaults)
    }

    private static func load(from defaults: any PreferenceStore) -> AppSettings {
        guard let data = defaults.data(forKey: defaultsKey) else { return AppSettings() }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            logger.error("settings could not be decoded: \(error.localizedDescription, privacy: .public)")
            return AppSettings()
        }
    }

    private func persist() {
        do {
            defaults.set(try JSONEncoder().encode(settings), forKey: Self.defaultsKey)
        } catch {
            Self.logger.error("settings could not be encoded: \(error.localizedDescription, privacy: .public)")
        }
    }
}
