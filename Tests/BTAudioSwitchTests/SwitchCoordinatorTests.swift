import Foundation
import Observation
import Testing
@testable import BTAudioSwitch

@MainActor
@Suite("切替の司令塔")
struct SwitchCoordinatorTests {
    private static let address = "0A:1B:2C:3D:4E:5F"
    private static let outputUID = "\(address):output"
    private static let inputUID = "\(address):input"
    private static let outputDevice = AudioDevice(
        uid: outputUID, name: "Headphone X2", transport: .bluetooth, hasOutput: true, hasInput: false
    )
    private static let inputDevice = AudioDevice(
        uid: inputUID, name: "Headphone X2", transport: .bluetooth, hasOutput: false, hasInput: true
    )

    private func withCoordinator(
        devices: [AudioDevice] = [],
        registeredDevice: RegisteredDevice? = RegisteredDevice(address: address, name: "Headphone X2"),
        configure: (inout AppSettings) -> Void = { _ in },
        waitForSettleTimeout: @escaping @Sendable () async -> Void = {},
        _ body: (SwitchCoordinator, FakeAudioDeviceDirectory, FakeBluetoothDirectory, SettingsStore) async throws -> Void
    ) async rethrows {
        let store = SettingsStore(defaults: MemoryPreferences())
        store.settings.registeredDevice = registeredDevice
        configure(&store.settings)
        let audio = FakeAudioDeviceDirectory(devices: devices)
        let bluetooth = FakeBluetoothDirectory()
        let coordinator = SwitchCoordinator(audio: audio, bluetooth: bluetooth, settingsStore: store, waitForSettleTimeout: { await waitForSettleTimeout() })
        try await body(coordinator, audio, bluetooth, store)
    }

    // 解除されなければ回数の上限で抜け、期待の側で落とす
    private func yieldUntil(_ condition: () -> Bool) async {
        for _ in 0..<1000 where !condition() { await Task.yield() }
    }

    private final class ChangeFlag: @unchecked Sendable {
        var fired = false
    }

    private func observeConnection(_ coordinator: SwitchCoordinator) -> ChangeFlag {
        let flag = ChangeFlag()
        withObservationTracking {
            _ = coordinator.isRegisteredDeviceConnected
        } onChange: {
            flag.fired = true
        }
        return flag
    }

    @Test("一覧変更の通知で接続状態が変わると、接続状態の監視に変化が届く")
    func connectionChangeFromDeviceListIsObservable() async {
        await withCoordinator { coordinator, audio, _, _ in
            coordinator.start()
            let flag = observeConnection(coordinator)
            audio.setDevices([Self.outputDevice])
            audio.fireDeviceListChanged()
            #expect(flag.fired)
        }
    }

    @Test("登録機器の変更で接続状態が変わると、接続状態の監視に変化が届く")
    func connectionChangeFromRegistrationIsObservable() async {
        await withCoordinator(devices: [Self.outputDevice], registeredDevice: nil) { coordinator, _, _, store in
            coordinator.start()
            let flag = observeConnection(coordinator)
            store.settings.registeredDevice = RegisteredDevice(address: Self.address, name: "Headphone X2")
            #expect(flag.fired)
        }
    }

    @Test("起動時は接続済みでも書かない")
    func startDoesNotWriteEvenWhenAlreadyConnected() async {
        await withCoordinator(devices: [Self.outputDevice]) { coordinator, audio, _, _ in
            coordinator.start()
            #expect(audio.writes.isEmpty)
            #expect(coordinator.isRegisteredDeviceConnected)
        }
    }

    @Test("出力の出現の通知で計画どおりに 1 回書く")
    func writesOutputOnAppearanceNotification() async {
        await withCoordinator { coordinator, audio, _, _ in
            coordinator.start()
            audio.setDevices([Self.outputDevice])
            audio.fireDeviceListChanged()
            #expect(audio.writes == [DefaultWrite(direction: .output, uid: Self.outputUID)])
        }
    }

    @Test("同じ一覧の通知を重ねても書かない")
    func repeatedNotificationWithSameListWritesNothing() async {
        await withCoordinator { coordinator, audio, _, _ in
            coordinator.start()
            audio.setDevices([Self.outputDevice])
            audio.fireDeviceListChanged()
            let countAfterFirst = audio.writes.count
            audio.fireDeviceListChanged()
            #expect(audio.writes.count == countAfterFirst)
        }
    }

    @Test("登録機器が無ければ通知が来ても書かない")
    func noRegisteredDeviceWritesNothing() async {
        await withCoordinator(registeredDevice: nil) { coordinator, audio, _, _ in
            coordinator.start()
            audio.setDevices([Self.outputDevice])
            audio.fireDeviceListChanged()
            #expect(audio.writes.isEmpty)
        }
    }

    @Test("設定の変更は取り直すだけで書かない")
    func settingsChangeRefreshesWithoutWriting() async {
        await withCoordinator(devices: [Self.outputDevice], registeredDevice: nil) { coordinator, audio, _, store in
            coordinator.start()
            #expect(!coordinator.isRegisteredDeviceConnected)
            store.settings.registeredDevice = RegisteredDevice(address: Self.address, name: "Headphone X2")
            #expect(audio.writes.isEmpty)
            #expect(coordinator.isRegisteredDeviceConnected)
        }
    }

    @Test("登録機器と関係のない設定の変更では一覧を取り直さない")
    func unrelatedSettingsChangeDoesNotRefreshDeviceList() async {
        await withCoordinator(devices: [Self.outputDevice]) { coordinator, audio, _, store in
            coordinator.start()
            let countAfterStart = audio.devicesCallCount
            store.settings.iconVisibility = .whileConnected
            store.settings.switchesInput = true
            #expect(audio.devicesCallCount == countAfterStart)
        }
    }

    @Test("登録機器の変更では一覧を取り直す")
    func registeredDeviceChangeRefreshesDeviceList() async {
        await withCoordinator(devices: [Self.outputDevice], registeredDevice: nil) { coordinator, audio, _, store in
            coordinator.start()
            let countAfterStart = audio.devicesCallCount
            store.settings.registeredDevice = RegisteredDevice(address: Self.address, name: "Headphone X2")
            #expect(audio.devicesCallCount == countAfterStart + 1)
        }
    }

    @Test("接続中の登録機器を解除すると isRegisteredDeviceConnected が false になり書き込みはしない")
    func unregisteringDropsConnectedFlagWithoutWriting() async {
        await withCoordinator(devices: [Self.outputDevice]) { coordinator, audio, _, store in
            coordinator.start()
            #expect(coordinator.isRegisteredDeviceConnected)
            store.settings.registeredDevice = nil
            #expect(!coordinator.isRegisteredDeviceConnected)
            #expect(audio.writes.isEmpty)
        }
    }

    @Test("接続中の機器から未接続の機器へ登録を変えると isRegisteredDeviceConnected が false になり書き込まない")
    func changingToDisconnectedDeviceDropsConnectedFlagWithoutWriting() async {
        let unconnected = RegisteredDevice(address: "AA:BB:CC:DD:EE:FF", name: "Other")
        await withCoordinator(devices: [Self.outputDevice]) { coordinator, audio, _, store in
            coordinator.start()
            #expect(coordinator.isRegisteredDeviceConnected)
            store.settings.registeredDevice = unconnected
            #expect(!coordinator.isRegisteredDeviceConnected)
            #expect(audio.writes.isEmpty)
        }
    }

    @Test("一覧変更の通知で出力が消失したとき、フォールバック先へ 1 回書く")
    func writesOutputFallbackOnceWhenOutputVanishes() async {
        let fallback = AudioDevice(uid: "fallback-output", name: "Fallback", transport: .other, hasOutput: true, hasInput: false)
        await withCoordinator(
            devices: [Self.outputDevice, fallback],
            configure: {
                $0.outputFallbackMode = .priorityList
                $0.outputFallback = [DeviceRef(uid: fallback.uid, name: fallback.name)]
            }
        ) { coordinator, audio, _, _ in
            coordinator.start()
            audio.setDevices([fallback])
            audio.fireDeviceListChanged()
            #expect(audio.writes == [DefaultWrite(direction: .output, uid: fallback.uid)])
        }
    }

    @Test("switchesInput が ON のとき、入力の出現が通知経由で書かれる")
    func writesInputOnAppearanceWhenSwitchesInputIsOn() async {
        await withCoordinator(configure: { $0.switchesInput = true }) { coordinator, audio, _, _ in
            coordinator.start()
            audio.setDevices([Self.inputDevice])
            audio.fireDeviceListChanged()
            #expect(audio.writes == [DefaultWrite(direction: .input, uid: Self.inputUID)])
        }
    }

    @Test("switchesInput が ON で inputFallbackMode が priorityList のとき、入力の消失通知でフォールバック先へ書く")
    func writesInputFallbackWhenInputVanishesWithPriorityList() async {
        let fallback = AudioDevice(uid: "fallback-input", name: "Fallback Mic", transport: .other, hasOutput: false, hasInput: true)
        await withCoordinator(
            devices: [Self.inputDevice, fallback],
            configure: {
                $0.switchesInput = true
                $0.inputFallbackMode = .priorityList
                $0.inputFallback = [DeviceRef(uid: fallback.uid, name: fallback.name)]
            }
        ) { coordinator, audio, _, _ in
            coordinator.start()
            audio.setDevices([fallback])
            audio.fireDeviceListChanged()
            #expect(audio.writes == [DefaultWrite(direction: .input, uid: fallback.uid)])
        }
    }

    @Test("一覧変更の通知で devices と isRegisteredDeviceConnected が更新される")
    func devicesAndConnectedFlagUpdateOnNotification() async {
        await withCoordinator { coordinator, audio, _, _ in
            coordinator.start()
            #expect(!coordinator.isRegisteredDeviceConnected)
            audio.setDevices([Self.outputDevice])
            audio.fireDeviceListChanged()
            #expect(coordinator.devices == [Self.outputDevice])
            #expect(coordinator.isRegisteredDeviceConnected)
        }
    }

    @Test("登録機器が無ければ disconnect は何もしない")
    func disconnectDoesNothingWithoutRegisteredDevice() async {
        await withCoordinator(registeredDevice: nil) { coordinator, audio, bluetooth, _ in
            await coordinator.disconnect()
            #expect(bluetooth.disconnectedAddresses.isEmpty)
            #expect(audio.writes.isEmpty)
        }
    }

    @Test("disconnect は登録アドレスで 1 回呼び、既定入出力は書かない")
    func disconnectCallsBluetoothOnceWithoutWritingDefaults() async {
        await withCoordinator { coordinator, audio, bluetooth, _ in
            await coordinator.disconnect()
            #expect(bluetooth.disconnectedAddresses == [Self.address])
            #expect(audio.writes.isEmpty)
        }
    }

    @Test("登録機器が無ければ connect は何もしない")
    func connectDoesNothingWithoutRegisteredDevice() async {
        await withCoordinator(registeredDevice: nil) { coordinator, audio, bluetooth, _ in
            await coordinator.connect()
            #expect(bluetooth.connectedAddresses.isEmpty)
            #expect(audio.writes.isEmpty)
        }
    }

    @Test("connect は登録アドレスで 1 回呼び、既定入出力は書かない")
    func connectCallsBluetoothOnceWithoutWritingDefaults() async {
        await withCoordinator { coordinator, audio, bluetooth, _ in
            await coordinator.connect()
            #expect(bluetooth.connectedAddresses == [Self.address])
            #expect(audio.writes.isEmpty)
        }
    }

    @Test("接続処理中に connect / disconnect を呼んでも重ねて実行せず、終われば pendingOperation が戻る")
    func operationsDoNotOverlapWhileConnecting() async {
        await withCoordinator { coordinator, _, bluetooth, _ in
            let gate = OperationGate()
            bluetooth.whileConnecting = { _ in await gate.enter() }
            let first = Task { await coordinator.connect() }
            await gate.waitUntilEntered()
            #expect(coordinator.pendingOperation == .connecting)
            await coordinator.connect()
            await coordinator.disconnect()
            #expect(bluetooth.connectedAddresses == [Self.address])
            #expect(bluetooth.disconnectedAddresses.isEmpty)
            await gate.release()
            await first.value
            #expect(coordinator.pendingOperation == nil)
        }
    }

    @Test("切断処理中に connect / disconnect を呼んでも重ねて実行せず、終われば pendingOperation が戻る")
    func operationsDoNotOverlapWhileDisconnecting() async {
        await withCoordinator { coordinator, _, bluetooth, _ in
            let gate = OperationGate()
            bluetooth.whileDisconnecting = { _ in await gate.enter() }
            let first = Task { await coordinator.disconnect() }
            await gate.waitUntilEntered()
            #expect(coordinator.pendingOperation == .disconnecting)
            await coordinator.connect()
            await coordinator.disconnect()
            #expect(bluetooth.connectedAddresses.isEmpty)
            #expect(bluetooth.disconnectedAddresses == [Self.address])
            await gate.release()
            await first.value
            #expect(coordinator.pendingOperation == nil)
        }
    }

    @Test("切断が成功しても、登録機器が一覧から消えるまでは切断中のまま")
    func disconnectStaysPendingUntilDeviceVanishes() async {
        let gate = SettleTimeoutGate()
        await withCoordinator(devices: [Self.outputDevice], waitForSettleTimeout: { await gate.wait() }) { coordinator, audio, _, _ in
            coordinator.start()
            let operation = Task { await coordinator.disconnect() }
            await gate.waitUntilWaiting()
            #expect(coordinator.pendingOperation == .disconnecting)
            audio.setDevices([])
            audio.fireDeviceListChanged()
            await yieldUntil { coordinator.pendingOperation == nil }
            #expect(coordinator.pendingOperation == nil)
            await gate.release()
            await operation.value
        }
    }

    @Test("接続が成功しても、登録機器が一覧に現れるまでは接続中のまま")
    func connectStaysPendingUntilDeviceAppears() async {
        let gate = SettleTimeoutGate()
        await withCoordinator(waitForSettleTimeout: { await gate.wait() }) { coordinator, audio, _, _ in
            coordinator.start()
            let operation = Task { await coordinator.connect() }
            await gate.waitUntilWaiting()
            #expect(coordinator.pendingOperation == .connecting)
            audio.setDevices([Self.outputDevice])
            audio.fireDeviceListChanged()
            await yieldUntil { coordinator.pendingOperation == nil }
            #expect(coordinator.pendingOperation == nil)
            await gate.release()
            await operation.value
        }
    }

    @Test("一覧に結果が現れないまま上限を過ぎると、処理中が解除される")
    func pendingOperationEndsAfterSettleTimeout() async {
        await withCoordinator(devices: [Self.outputDevice]) { coordinator, _, _, _ in
            coordinator.start()
            await coordinator.disconnect()
            #expect(coordinator.pendingOperation == nil)
            #expect(coordinator.isRegisteredDeviceConnected)
        }
    }

    @Test("OS 側で名前が変わっていたら、保存している登録機器の名前を合わせる")
    func syncsRenamedRegisteredDevice() async {
        await withCoordinator { coordinator, _, bluetooth, store in
            bluetooth.paired = [PairedDevice(address: Self.address, name: "BT Headphone", isAudio: true)]
            coordinator.syncRegisteredDeviceName()
            #expect(store.settings.registeredDevice == RegisteredDevice(address: Self.address, name: "BT Headphone"))
        }
    }

    @Test("ペアリング一覧に登録機器が無ければ、名前を変えない")
    func keepsNameWhenRegisteredDeviceIsNotPaired() async {
        await withCoordinator { coordinator, _, bluetooth, store in
            bluetooth.paired = [PairedDevice(address: "1A:2B:3C:4D:5E:6F", name: "別の機器", isAudio: true)]
            coordinator.syncRegisteredDeviceName()
            #expect(store.settings.registeredDevice == RegisteredDevice(address: Self.address, name: "Headphone X2"))
        }
    }
}

// bluetooth の呼び出しを止めて、次の connect/disconnect を確実に重ねる
private actor OperationGate {
    private var entered = false
    private var released = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    // 止めるのは最初の呼び出しだけ。重ねて呼ばれた分は素通りさせ、テストを止めずに回数で検出する
    func enter() async {
        guard !entered else { return }
        entered = true
        entryWaiters.forEach { $0.resume() }
        entryWaiters = []
        if released { return }
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilEntered() async {
        if entered { return }
        await withCheckedContinuation { entryWaiters.append($0) }
    }

    func release() {
        released = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters = []
    }
}

// 上限の待ちに入ったことを知らせ、テストが解放するまで上限を来させない
private actor SettleTimeoutGate {
    private var isWaiting = false
    private var waitingWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        isWaiting = true
        waitingWaiters.forEach { $0.resume() }
        waitingWaiters = []
        await withCheckedContinuation { releaseWaiters.append($0) }
    }

    func waitUntilWaiting() async {
        if isWaiting { return }
        await withCheckedContinuation { waitingWaiters.append($0) }
    }

    func release() {
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters = []
    }
}
