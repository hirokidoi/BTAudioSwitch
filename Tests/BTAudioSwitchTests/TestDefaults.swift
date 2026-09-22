import Foundation

enum TestDefaults {
    static let namePrefix = "BTAudioSwitchTests-"

    static func makeName() -> String { "\(namePrefix)\(UUID().uuidString)" }

    static func remove(name: String, defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: name)
    }
}
