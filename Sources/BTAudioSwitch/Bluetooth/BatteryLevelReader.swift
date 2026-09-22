import Foundation
import os

protocol BatteryLevelReader: Sendable {
    func batteryLevel(address: String) async -> Int?
}

enum BluetoothBatteryReport {
    private static let logger = Logger(subsystem: BundleInfo.subsystem, category: "battery")

    static func level(address: String, in json: Data) -> Int? {
        let report: Report
        do {
            report = try JSONDecoder().decode(Report.self, from: json)
        } catch {
            logger.error("system_profiler output could not be decoded: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        for controller in report.controllers {
            for entry in controller.connected ?? [] {
                for device in entry.values where device.address.map(BluetoothAddress.canonical) == address {
                    return device.batteryLevelMain
                        .flatMap { Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "%"))) }
                        .flatMap(BatteryLevel.valid)
                }
            }
        }
        return nil
    }

    private struct Report: Decodable {
        let controllers: [Controller]

        enum CodingKeys: String, CodingKey {
            case controllers = "SPBluetoothDataType"
        }
    }

    private struct Controller: Decodable {
        let connected: [[String: Device]]?

        enum CodingKeys: String, CodingKey {
            case connected = "device_connected"
        }
    }

    private struct Device: Decodable {
        let address: String?
        let batteryLevelMain: String?

        enum CodingKeys: String, CodingKey {
            case address = "device_address"
            case batteryLevelMain = "device_batteryLevelMain"
        }
    }
}

enum BatteryLevel {
    // 0 は「値が無い」を表すため、残量としては扱わない
    static func valid(_ level: Int) -> Int? {
        (1...100).contains(level) ? level : nil
    }
}

enum CommandOutput {
    private static let logger = Logger(subsystem: BundleInfo.subsystem, category: "battery")

    static func run(_ executable: URL, arguments: [String]) async -> Data? {
        await Task.detached(priority: .utility) {
            runToEnd(executable, arguments: arguments)
        }.value
    }

    private static func runToEnd(_ executable: URL, arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            logger.error("\(executable.lastPathComponent, privacy: .public) failed to launch: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        // 終了を先に待つと出力がパイプの容量を超えたときに双方が止まる
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            logger.error("\(executable.lastPathComponent, privacy: .public) exited status=\(process.terminationStatus, privacy: .public)")
            return nil
        }
        return data
    }
}

final class FallbackBatteryReader: BatteryLevelReader, Sendable {
    private let readers: [any BatteryLevelReader]

    init(_ readers: [any BatteryLevelReader]) {
        self.readers = readers
    }

    func batteryLevel(address: String) async -> Int? {
        for reader in readers {
            if let level = await reader.batteryLevel(address: address) { return level }
        }
        return nil
    }
}
