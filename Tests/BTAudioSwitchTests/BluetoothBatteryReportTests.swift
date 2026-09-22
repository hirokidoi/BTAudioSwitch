import Foundation
import Testing
@testable import BTAudioSwitch

@Suite("system_profiler の出力からの残量の読み取り")
struct BluetoothBatteryReportTests {
    private static let address = "0A:1B:2C:3D:4E:5F"

    private static func report(connected: String, notConnected: String = "") -> Data {
        Data("""
        {
          "SPBluetoothDataType": [
            {
              "controller_properties": { "controller_address": "0F:0E:0D:0C:0B:0A" },
              "device_connected": [\(connected)],
              "device_not_connected": [\(notConnected)]
            }
          ]
        }
        """.utf8)
    }

    private static let keyboard = """
    { "Keyboard": { "device_address": "1A:2B:3C:4D:5E:6F", "device_batteryLevelMain": "40%" } }
    """

    private static let headphone = """
    { "Headphone X2": { "device_address": "\(address)", "device_batteryLevelMain": "80%" } }
    """

    @Test("接続中の対象機器の残量を読める")
    func readsLevelOfTargetDevice() {
        let json = Self.report(connected: "\(Self.keyboard), \(Self.headphone)")
        #expect(BluetoothBatteryReport.level(address: Self.address, in: json) == 80)
    }

    @Test("出力側のアドレスの表記が揺れていても照合できる")
    func matchesNotationVariantsInOutput() {
        let json = Self.report(connected: """
        { "Headphone X2": { "device_address": "0a-1b-2c-3d-4e-5f", "device_batteryLevelMain": "80%" } }
        """)
        #expect(BluetoothBatteryReport.level(address: Self.address, in: json) == 80)
    }

    @Test("対象機器が接続中の一覧に無ければ nil")
    func nilWhenTargetNotConnected() {
        #expect(BluetoothBatteryReport.level(address: Self.address, in: Self.report(connected: Self.keyboard)) == nil)
        #expect(BluetoothBatteryReport.level(
            address: Self.address,
            in: Self.report(connected: Self.keyboard, notConnected: Self.headphone)
        ) == nil)
    }

    @Test("対象機器に残量の項目が無ければ nil")
    func nilWhenLevelMissing() {
        let json = Self.report(connected: """
        { "Headphone X2": { "device_address": "\(Self.address)", "device_minorType": "Headset" } }
        """)
        #expect(BluetoothBatteryReport.level(address: Self.address, in: json) == nil)
    }

    @Test("解釈できない出力なら nil")
    func nilWhenOutputIsNotReport() {
        #expect(BluetoothBatteryReport.level(address: Self.address, in: Data("not json".utf8)) == nil)
    }

    @Test("0% は値なしとして nil")
    func nilWhenLevelIsZero() {
        let json = Self.report(connected: """
        { "Headphone X2": { "device_address": "\(Self.address)", "device_batteryLevelMain": "0%" } }
        """)
        #expect(BluetoothBatteryReport.level(address: Self.address, in: json) == nil)
    }

    @Test("範囲外の残量は nil")
    func nilWhenLevelOutOfRange() {
        let json = Self.report(connected: """
        { "Headphone X2": { "device_address": "\(Self.address)", "device_batteryLevelMain": "150%" } }
        """)
        #expect(BluetoothBatteryReport.level(address: Self.address, in: json) == nil)
    }
}
