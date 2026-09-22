import IOBluetooth

final class IOBluetoothDirectory: BluetoothDirectory, Sendable {
    func pairedDevices() -> [PairedDevice] {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return devices.compactMap { device in
            guard let address = device.addressString else { return nil }
            return PairedDevice(
                address: BluetoothAddress.canonical(address),
                name: device.nameOrAddress ?? address,
                isAudio: isAudio(device)
            )
        }
    }

    private static let audioServiceClasses = [
        kBluetoothSDPUUID16ServiceClassAudioSink,
        kBluetoothSDPUUID16ServiceClassHandsFree,
        kBluetoothSDPUUID16ServiceClassHeadset,
    ]

    private func isAudio(_ device: IOBluetoothDevice) -> Bool {
        let isAudioMajorClass = device.deviceClassMajor == BluetoothDeviceClassMajor(kBluetoothDeviceClassMajorAudio)
        let hasAudioService = Self.audioServiceClasses.contains { serviceClass in
            device.getServiceRecord(for: IOBluetoothSDPUUID(uuid16: BluetoothSDPUUID16(serviceClass.rawValue))) != nil
        }
        return isAudioMajorClass || hasAudioService
    }

    func connect(address: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            guard let device = IOBluetoothDevice(addressString: address) else { return false }
            return device.openConnection() == kIOReturnSuccess
        }.value
    }

    func disconnect(address: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            guard let device = IOBluetoothDevice(addressString: address) else { return false }
            return device.closeConnection() == kIOReturnSuccess
        }.value
    }
}
