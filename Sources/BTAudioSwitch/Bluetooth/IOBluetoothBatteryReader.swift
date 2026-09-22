import IOBluetooth

final class IOBluetoothBatteryReader: BatteryLevelReader, Sendable {
    private static let key = "batteryPercentSingle"

    func batteryLevel(address: String) async -> Int? {
        await MainActor.run {
            guard let device = IOBluetoothDevice(addressString: address),
                  device.responds(to: NSSelectorFromString(Self.key)),
                  let level = (device.value(forKey: Self.key) as? NSNumber)?.intValue
            else { return nil }
            return BatteryLevel.valid(level)
        }
    }
}
