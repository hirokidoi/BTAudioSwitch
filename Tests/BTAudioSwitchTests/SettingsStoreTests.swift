import Foundation
import Testing
@testable import BTAudioSwitch

@MainActor
@Suite("設定の保存")
struct SettingsStoreTests {
    private func withStore(_ body: (SettingsStore, MemoryPreferences) throws -> Void) rethrows {
        let defaults = MemoryPreferences()
        try body(SettingsStore(defaults: defaults), defaults)
    }

    @Test("記録が無ければ既定値になる")
    func defaultsWhenNoRecord() {
        withStore { store, _ in
            #expect(store.settings == AppSettings())
        }
    }

    @Test("壊れた JSON は既定値になる")
    func defaultsWhenCorrupted() {
        withStore { _, defaults in
            defaults.set("not json".data(using: .utf8), forKey: SettingsStore.defaultsKey)
            let store = SettingsStore(defaults: defaults)
            #expect(store.settings == AppSettings())
        }
    }

    @Test("保存した値が読み直しで往復する")
    func roundTrips() {
        withStore { store, defaults in
            store.settings.registeredDevice = RegisteredDevice(address: "0A:1B:2C:3D:4E:5F", name: "Headphone X2")
            store.settings.switchesInput = true
            store.settings.inputFallbackMode = .priorityList
            store.settings.outputFallbackMode = .priorityList
            store.settings.outputFallback = [DeviceRef(uid: "uid-out", name: "スピーカー")]
            store.settings.inputFallback = [DeviceRef(uid: "uid-in", name: "マイク")]
            store.settings.iconVisibility = .whileConnected

            let reloaded = SettingsStore(defaults: defaults)
            #expect(reloaded.settings == store.settings)
        }
    }

    @Test("一部のキーを欠いた JSON は、欠けたキーだけ既定値で補われる")
    func decodesMissingKeysAsDefaults() throws {
        var settings = AppSettings()
        settings.registeredDevice = RegisteredDevice(address: "0A:1B:2C:3D:4E:5F", name: "Headphone X2")
        settings.outputFallbackMode = .priorityList
        settings.outputFallback = [DeviceRef(uid: "uid-out", name: "スピーカー")]

        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        json.removeValue(forKey: "iconVisibility")
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.iconVisibility == AppSettings().iconVisibility)
        #expect(decoded.registeredDevice == settings.registeredDevice)
        #expect(decoded.outputFallbackMode == settings.outputFallbackMode)
        #expect(decoded.outputFallback == settings.outputFallback)
    }
}
