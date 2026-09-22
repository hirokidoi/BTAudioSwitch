@testable import BTAudioSwitch

final class FakeBluetoothDirectory: BluetoothDirectory, @unchecked Sendable {
    private(set) var connectedAddresses: [String] = []
    private(set) var disconnectedAddresses: [String] = []
    var whileConnecting: (@Sendable (String) async -> Void)?
    var whileDisconnecting: (@Sendable (String) async -> Void)?

    var paired: [PairedDevice] = []

    func pairedDevices() -> [PairedDevice] { paired }

    func connect(address: String) async -> Bool {
        connectedAddresses.append(address)
        await whileConnecting?(address)
        return true
    }

    func disconnect(address: String) async -> Bool {
        disconnectedAddresses.append(address)
        await whileDisconnecting?(address)
        return true
    }
}

final class FakeAudioDeviceDirectory: AudioDeviceDirectory, @unchecked Sendable {
    private var storedDevices: [AudioDevice]
    private(set) var writes: [DefaultWrite] = []
    private(set) var devicesCallCount = 0
    private var handler: (@MainActor @Sendable () -> Void)?

    init(devices: [AudioDevice] = []) {
        storedDevices = devices
    }

    func devices() -> [AudioDevice] {
        devicesCallCount += 1
        return storedDevices
    }

    func setDevices(_ devices: [AudioDevice]) {
        storedDevices = devices
    }

    func setDefault(_ direction: Direction, uid: String) -> Bool {
        writes.append(DefaultWrite(direction: direction, uid: uid))
        return true
    }

    func observeDeviceListChanges(_ handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
    }

    @MainActor
    func fireDeviceListChanged() {
        handler?()
    }
}

final class FakeBatteryLevelReader: BatteryLevelReader, @unchecked Sendable {
    var level: Int?
    var whileReading: (@Sendable (String) async -> Void)?
    private(set) var requestedAddresses: [String] = []

    init(level: Int? = nil) {
        self.level = level
    }

    func batteryLevel(address: String) async -> Int? {
        requestedAddresses.append(address)
        await whileReading?(address)
        return level
    }
}
