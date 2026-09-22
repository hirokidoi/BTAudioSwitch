import IOBluetooth

final class IOBluetoothBatteryReader: BatteryLevelReader, Sendable {
    static let argument = "--read-battery-level"
    private static let key = "batteryPercentSingle"

    func batteryLevel(address: String) async -> Int? {
        guard let executable = Bundle.main.executableURL,
              let output = await CommandOutput.run(executable, arguments: [Self.argument, address])
        else { return nil }
        return Self.level(fromOutput: output)
    }

    static func level(fromOutput output: Data) -> Int? {
        Int(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap(BatteryLevel.valid)
    }

    static func readInProcess(address: String) -> Int? {
        guard let device = IOBluetoothDevice(addressString: address),
              device.responds(to: NSSelectorFromString(key)),
              let level = (device.value(forKey: key) as? NSNumber)?.intValue
        else { return nil }
        return BatteryLevel.valid(level)
    }
}
