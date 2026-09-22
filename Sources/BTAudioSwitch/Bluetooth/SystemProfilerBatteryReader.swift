import Foundation
import os

final class SystemProfilerBatteryReader: BatteryLevelReader, Sendable {
    private static let logger = Logger(subsystem: BundleInfo.subsystem, category: "battery")

    func batteryLevel(address: String) async -> Int? {
        await Task.detached(priority: .utility) {
            guard let output = Self.bluetoothReport() else { return nil }
            return BluetoothBatteryReport.level(address: address, in: output)
        }.value
    }

    private static func bluetoothReport() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            logger.error("system_profiler failed to launch: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        // 終了を先に待つと出力がパイプの容量を超えたときに双方が止まる
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            logger.error("system_profiler exited status=\(process.terminationStatus, privacy: .public)")
            return nil
        }
        return data
    }
}
