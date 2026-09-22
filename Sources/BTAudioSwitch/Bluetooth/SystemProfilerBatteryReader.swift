import Foundation

final class SystemProfilerBatteryReader: BatteryLevelReader, Sendable {
    func batteryLevel(address: String) async -> Int? {
        guard let output = await CommandOutput.run(
            URL(fileURLWithPath: "/usr/sbin/system_profiler"),
            arguments: ["SPBluetoothDataType", "-json"]
        ) else { return nil }
        return BluetoothBatteryReport.level(address: address, in: output)
    }
}
