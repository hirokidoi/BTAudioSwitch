import Foundation
import os

enum ConnectionOperation {
    case connecting
    case disconnecting
}

@MainActor
@Observable
final class SwitchCoordinator {
    private static let logger = Logger(subsystem: BundleInfo.subsystem, category: "switching")

    private let audio: any AudioDeviceDirectory
    private let bluetooth: any BluetoothDirectory
    private let settingsStore: SettingsStore
    private let waitForSettleTimeout: @Sendable () async throws -> Void
    @ObservationIgnored private var lastRegisteredDevice: RegisteredDevice?
    @ObservationIgnored private var settleWaiter: (connected: Bool, continuation: CheckedContinuation<Void, Never>)?

    private(set) var devices: [AudioDevice] = []
    private(set) var registeredEndpoints = Endpoints()
    private(set) var pendingOperation: ConnectionOperation?

    var isRegisteredDeviceConnected: Bool { registeredEndpoints.isConnected }

    init(
        audio: any AudioDeviceDirectory,
        bluetooth: any BluetoothDirectory,
        settingsStore: SettingsStore,
        waitForSettleTimeout: @escaping @Sendable () async throws -> Void = { try await Task.sleep(for: .seconds(5)) } // 設計値
    ) {
        self.audio = audio
        self.bluetooth = bluetooth
        self.settingsStore = settingsStore
        self.waitForSettleTimeout = waitForSettleTimeout
        lastRegisteredDevice = settingsStore.settings.registeredDevice
        settingsStore.onChange = { [weak self] in self?.registeredDeviceMayHaveChanged() }
    }

    func syncRegisteredDeviceName() {
        guard let registered = settingsStore.settings.registeredDevice,
              let paired = bluetooth.pairedDevices().first(where: { $0.address == registered.address }),
              paired.name != registered.name
        else { return }
        settingsStore.settings.registeredDevice = RegisteredDevice(address: registered.address, name: paired.name)
    }

    func start() {
        refreshSnapshot()
        audio.observeDeviceListChanges { [weak self] in self?.deviceListChanged() }
    }

    func connect() async {
        guard pendingOperation == nil, let device = settingsStore.settings.registeredDevice else { return }
        pendingOperation = .connecting
        defer { pendingOperation = nil }
        let success = await bluetooth.connect(address: device.address)
        Self.logger.info("connect address=\(device.address, privacy: .private(mask: .hash)) success=\(success, privacy: .public)")
        if success { await waitUntilConnection(is: true) }
    }

    func disconnect() async {
        guard pendingOperation == nil, let device = settingsStore.settings.registeredDevice else { return }
        pendingOperation = .disconnecting
        defer { pendingOperation = nil }
        let success = await bluetooth.disconnect(address: device.address)
        Self.logger.info("disconnect address=\(device.address, privacy: .private(mask: .hash)) success=\(success, privacy: .public)")
        if success { await waitUntilConnection(is: false) }
    }

    private func waitUntilConnection(is connected: Bool) async {
        guard isRegisteredDeviceConnected != connected else { return }
        let timeout = Task { [weak self, waitForSettleTimeout] in
            do { try await waitForSettleTimeout() } catch { return }
            self?.resumeSettleWaiter()
        }
        await withCheckedContinuation { settleWaiter = (connected, $0) }
        timeout.cancel()
    }

    private func resumeSettleWaiter() {
        settleWaiter?.continuation.resume()
        settleWaiter = nil
    }

    private func resumeSettleWaiterIfSettled() {
        if let waiter = settleWaiter, waiter.connected == isRegisteredDeviceConnected { resumeSettleWaiter() }
    }

    private func deviceListChanged() {
        let newEndpoints = refreshDevicesAndEndpoints()
        logChanges(old: registeredEndpoints, new: newEndpoints)
        let plan = SwitchPlan.make(old: registeredEndpoints, new: newEndpoints, settings: settingsStore.settings, devices: devices)
        for write in plan {
            let success = audio.setDefault(write.direction, uid: write.uid)
            Self.logger.info("write direction=\(String(describing: write.direction), privacy: .public) uid=\(write.uid, privacy: .private(mask: .hash)) success=\(success, privacy: .public)")
        }
        registeredEndpoints = newEndpoints
        resumeSettleWaiterIfSettled()
    }

    private func registeredDeviceMayHaveChanged() {
        let current = settingsStore.settings.registeredDevice
        guard current != lastRegisteredDevice else { return }
        lastRegisteredDevice = current
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        registeredEndpoints = refreshDevicesAndEndpoints()
        resumeSettleWaiterIfSettled()
    }

    private func refreshDevicesAndEndpoints() -> Endpoints {
        devices = audio.devices()
        return currentEndpoints()
    }

    private func currentEndpoints() -> Endpoints {
        guard let device = settingsStore.settings.registeredDevice else { return Endpoints() }
        return BluetoothEndpointMatch.endpoints(for: device.address, in: devices)
    }

    private func logChanges(old: Endpoints, new: Endpoints) {
        for direction in Direction.allCases {
            switch EndpointChange.between(old[direction], new[direction]) {
            case nil:
                continue
            case .appeared(let uid):
                Self.logger.info("change direction=\(String(describing: direction), privacy: .public) change=appeared uid=\(uid, privacy: .private(mask: .hash))")
            case .vanished:
                Self.logger.info("change direction=\(String(describing: direction), privacy: .public) change=vanished")
            }
        }
    }
}
