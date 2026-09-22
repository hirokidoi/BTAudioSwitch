import Foundation

enum BundleInfo {
    private static let fallbackName = "BTAudioSwitch"

    static var subsystem: String { Bundle.main.bundleIdentifier ?? fallbackName }
    static var productName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? fallbackName
    }
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
}
