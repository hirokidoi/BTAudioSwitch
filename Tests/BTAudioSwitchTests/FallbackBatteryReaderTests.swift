import Testing
@testable import BTAudioSwitch

@Suite("残量の取得元の切り替え")
struct FallbackBatteryReaderTests {
    @Test("先の取得元が値を返せば、後の取得元は呼ばない")
    func usesFirstAvailableLevel() async {
        let first = FakeBatteryLevelReader(level: 90)
        let second = FakeBatteryLevelReader(level: 50)
        let level = await FallbackBatteryReader([first, second]).batteryLevel(address: "0A:1B:2C:3D:4E:5F")
        #expect(level == 90)
        #expect(second.requestedAddresses.isEmpty)
    }

    @Test("先の取得元が値を返さなければ、後の取得元を使う")
    func fallsBackWhenFirstHasNoLevel() async {
        let first = FakeBatteryLevelReader(level: nil)
        let second = FakeBatteryLevelReader(level: 50)
        let level = await FallbackBatteryReader([first, second]).batteryLevel(address: "0A:1B:2C:3D:4E:5F")
        #expect(level == 50)
    }

    @Test("どの取得元も値を返さなければ nil")
    func returnsNilWhenNoneHasLevel() async {
        let level = await FallbackBatteryReader([FakeBatteryLevelReader(), FakeBatteryLevelReader()])
            .batteryLevel(address: "0A:1B:2C:3D:4E:5F")
        #expect(level == nil)
    }

    @Test("0 と範囲外は残量として扱わない")
    func rejectsZeroAndOutOfRange() {
        #expect(BatteryLevel.valid(0) == nil)
        #expect(BatteryLevel.valid(101) == nil)
        #expect(BatteryLevel.valid(1) == 1)
        #expect(BatteryLevel.valid(100) == 100)
    }
}
