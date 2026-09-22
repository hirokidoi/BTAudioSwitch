import Testing
@testable import BTAudioSwitch

@MainActor
@Suite("電池アイコンの読み分け")
struct BatteryIndicatorTests {
    @Test("空と満タンはそれぞれ両端のアイコンになる")
    func endsMapToEndSymbols() {
        #expect(BatteryIndicator.symbolName(for: 0) == "battery.0percent")
        #expect(BatteryIndicator.symbolName(for: 100) == "battery.100percent")
    }

    @Test("未取得は空のアイコンになる")
    func unknownLevelIsEmpty() {
        #expect(BatteryIndicator.symbolName(for: nil) == "battery.0percent")
    }

    @Test("途中の残量は最も近い段階のアイコンになる")
    func intermediateLevelsRoundToNearestStep() {
        #expect(BatteryIndicator.symbolName(for: 10) == "battery.0percent")
        #expect(BatteryIndicator.symbolName(for: 40) == "battery.50percent")
        #expect(BatteryIndicator.symbolName(for: 80) == "battery.75percent")
    }

    @Test("範囲外の値は両端に収める")
    func outOfRangeIsClamped() {
        #expect(BatteryIndicator.symbolName(for: -5) == "battery.0percent")
        #expect(BatteryIndicator.symbolName(for: 120) == "battery.100percent")
    }
}
