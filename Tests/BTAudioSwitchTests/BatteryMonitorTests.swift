import Foundation
import Testing
@testable import BTAudioSwitch

@Suite("残量の保持値の扱い")
struct BatteryReadingTests {
    private static let address = "0A:1B:2C:3D:4E:5F"
    private static let otherAddress = "1A:2B:3C:4D:5E:6F"
    private static let reading = BatteryReading(address: address, level: 80)

    @Test("登録機器のアドレスと一致する保持値だけを表示する")
    func displaysOnlyForRegisteredAddress() {
        #expect(BatteryReading.displayed(Self.reading, registeredAddress: Self.address) == 80)
        #expect(BatteryReading.displayed(Self.reading, registeredAddress: Self.otherAddress) == nil)
        #expect(BatteryReading.displayed(Self.reading, registeredAddress: nil) == nil)
        #expect(BatteryReading.displayed(nil, registeredAddress: Self.address) == nil)
    }

    @Test("取得値は取得を始めたアドレスと組にして保持する")
    func storesFetchedLevelWithAddress() {
        let updated = BatteryReading.updated(nil, fetched: 60, requestedAddress: Self.address, registeredAddress: Self.address)
        #expect(updated == BatteryReading(address: Self.address, level: 60))
    }

    @Test("取得に失敗したら保持値を変えない")
    func keepsReadingWhenFetchFails() {
        let updated = BatteryReading.updated(Self.reading, fetched: nil, requestedAddress: Self.address, registeredAddress: Self.address)
        #expect(updated == Self.reading)
    }

    @Test("取得中に登録機器が変わったら取得値を捨てる")
    func discardsFetchedLevelWhenRegistrationChanged() {
        let updated = BatteryReading.updated(Self.reading, fetched: 60, requestedAddress: Self.address, registeredAddress: Self.otherAddress)
        #expect(updated == Self.reading)
        #expect(BatteryReading.displayed(updated, registeredAddress: Self.otherAddress) == nil)
    }
}

@MainActor
@Suite("残量の監視")
struct BatteryMonitorTests {
    private static let address = "0A:1B:2C:3D:4E:5F"
    private static let otherDevice = RegisteredDevice(address: "1A:2B:3C:4D:5E:6F", name: "Speaker")

    private func withMonitor(
        reader: FakeBatteryLevelReader,
        _ body: (BatteryMonitor, SettingsStore) async throws -> Void
    ) async rethrows {
        let store = SettingsStore(defaults: MemoryPreferences())
        store.settings.registeredDevice = RegisteredDevice(address: Self.address, name: "Headphone X2")
        try await body(BatteryMonitor(reader: reader, settingsStore: store), store)
    }

    @Test("一度も取れていなければ nil、取れたらその値")
    func levelAfterRefresh() async {
        let reader = FakeBatteryLevelReader(level: 80)
        await withMonitor(reader: reader) { monitor, _ in
            #expect(monitor.level == nil)
            await monitor.refresh()
            #expect(monitor.level == 80)
        }
    }

    @Test("取得に失敗しても直前の値を表示し続ける")
    func keepsLevelWhenRefreshFails() async {
        let reader = FakeBatteryLevelReader(level: 80)
        await withMonitor(reader: reader) { monitor, _ in
            await monitor.refresh()
            reader.level = nil
            await monitor.refresh()
            #expect(monitor.level == 80)
        }
    }

    @Test("登録機器を変えると前の機器の値は表示しない")
    func hidesLevelAfterRegistrationChange() async {
        let reader = FakeBatteryLevelReader(level: 80)
        await withMonitor(reader: reader) { monitor, store in
            await monitor.refresh()
            store.settings.registeredDevice = Self.otherDevice
            #expect(monitor.level == nil)
        }
    }

    @Test("取得中に登録機器が変わったら取得値を捨てる")
    func discardsLevelFetchedForPreviousRegistration() async {
        let reader = FakeBatteryLevelReader(level: 80)
        await withMonitor(reader: reader) { monitor, store in
            reader.whileReading = { _ in
                await MainActor.run { store.settings.registeredDevice = Self.otherDevice }
            }
            await monitor.refresh()
            #expect(monitor.level == nil)
            store.settings.registeredDevice = RegisteredDevice(address: Self.address, name: "Headphone X2")
            #expect(monitor.level == nil)
        }
    }

    @Test("同じ機器の取得中に refresh() を呼んでも reader の呼び出しは 1 回で、両方が同じ結果を受け取る")
    func concurrentRefreshSharesInFlightFetch() async {
        let reader = FakeBatteryLevelReader(level: 80)
        let gate = ReadingGate()
        reader.whileReading = { address in await gate.enter(address) }
        await withMonitor(reader: reader) { monitor, _ in
            let first = Task { await monitor.refresh() }
            await gate.waitUntilEntered(Self.address)
            let second = Task { await monitor.refresh() }
            await Task.yield()
            await gate.release(Self.address)
            _ = await (first.value, second.value)
            #expect(reader.requestedAddresses == [Self.address])
            #expect(monitor.level == 80)
        }
    }

    @Test("別の機器の取得中に登録を変えたら、変えた先の機器を取りに行く")
    func refreshFetchesNewRegistrationWhilePreviousFetchIsInFlight() async {
        let reader = FakeBatteryLevelReader(level: 80)
        let gate = ReadingGate()
        reader.whileReading = { address in await gate.enter(address) }
        await gate.release(Self.otherDevice.address)
        await withMonitor(reader: reader) { monitor, store in
            let first = Task { await monitor.refresh() }
            await gate.waitUntilEntered(Self.address)
            store.settings.registeredDevice = Self.otherDevice
            let second = Task { await monitor.refresh() }
            await Task.yield()
            await gate.release(Self.address)
            _ = await (first.value, second.value)
            #expect(reader.requestedAddresses == [Self.address, Self.otherDevice.address])
            #expect(monitor.level == 80)
        }
    }

    @Test("前の機器の取得が終わっても、今の機器の取得中の refresh() はその取得を待つ")
    func finishingPreviousFetchKeepsCurrentFetchShared() async {
        let reader = FakeBatteryLevelReader(level: 80)
        let gate = ReadingGate()
        reader.whileReading = { address in await gate.enter(address) }
        await withMonitor(reader: reader) { monitor, store in
            let first = Task { await monitor.refresh() }
            await gate.waitUntilEntered(Self.address)
            store.settings.registeredDevice = Self.otherDevice
            let second = Task { await monitor.refresh() }
            await Task.yield()
            await gate.release(Self.address)
            await first.value
            let third = Task { await monitor.refresh() }
            await Task.yield()
            await gate.release(Self.otherDevice.address)
            _ = await (second.value, third.value)
            #expect(reader.requestedAddresses == [Self.address, Self.otherDevice.address])
        }
    }
}

// reader の呼び出しを機器ごとに止めて、次の refresh() を確実に重ねる
private actor ReadingGate {
    private var entered: Set<String> = []
    private var released: Set<String> = []
    private var entryWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var releaseWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func enter(_ address: String) async {
        entered.insert(address)
        entryWaiters.removeValue(forKey: address)?.forEach { $0.resume() }
        if released.contains(address) { return }
        await withCheckedContinuation { releaseWaiters[address, default: []].append($0) }
    }

    func waitUntilEntered(_ address: String) async {
        if entered.contains(address) { return }
        await withCheckedContinuation { entryWaiters[address, default: []].append($0) }
    }

    func release(_ address: String) {
        released.insert(address)
        releaseWaiters.removeValue(forKey: address)?.forEach { $0.resume() }
    }
}
