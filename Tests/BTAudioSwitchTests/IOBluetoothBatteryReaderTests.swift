import Foundation
import Testing
@testable import BTAudioSwitch

@Suite("子プロセスの出力からの残量の読み取り")
struct IOBluetoothBatteryReaderTests {
    @Test("改行付きの数値を残量として読む")
    func readsLevel() {
        #expect(IOBluetoothBatteryReader.level(fromOutput: Data("80\n".utf8)) == 80)
    }

    @Test("空・数値でない・残量として無効な出力は nil", arguments: ["", "abc", "0\n", "101\n"])
    func rejectsInvalidOutput(output: String) {
        #expect(IOBluetoothBatteryReader.level(fromOutput: Data(output.utf8)) == nil)
    }
}
