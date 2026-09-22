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
