import Testing
@testable import BTAudioSwitch

@Suite("BT エンドポイントの対応付け")
struct BluetoothEndpointMatchTests {
    private static let registeredAddress = "0A:1B:2C:3D:4E:5F"

    private static let devices: [AudioDevice] = [
        AudioDevice(
            uid: "0A-1B-2C-3D-4E-5F:input", name: "Headphone X2",
            transport: .bluetooth, hasOutput: false, hasInput: true
        ),
        AudioDevice(
            uid: "0A-1B-2C-3D-4E-5F:output", name: "Headphone X2",
            transport: .bluetooth, hasOutput: true, hasInput: false
        ),
        AudioDevice(
            uid: "BuiltInSpeakerDevice", name: "Mac miniのスピーカー",
            transport: .other, hasOutput: true, hasInput: false
        ),
    ]

    @Test("正規化済みの登録アドレスで出力・入力のエンドポイントが引ける")
    func resolvesOutputAndInputEndpoints() {
        let endpoints = BluetoothEndpointMatch.endpoints(for: Self.registeredAddress, in: Self.devices)
        #expect(endpoints.output == "0A-1B-2C-3D-4E-5F:output")
        #expect(endpoints.input == "0A-1B-2C-3D-4E-5F:input")
    }

    @Test("他機器の UID には反応しない")
    func ignoresOtherDevices() {
        let endpoints = BluetoothEndpointMatch.endpoints(for: "AA:BB:CC:DD:EE:FF", in: Self.devices)
        #expect(endpoints.output == nil)
        #expect(endpoints.input == nil)
    }

    @Test("Bluetooth/BLE 以外の転送種別は UID が一致しても対象にしない")
    func ignoresNonBluetoothTransport() {
        let device = AudioDevice(
            uid: "0A-1B-2C-3D-4E-5F:virtual", name: "偽装デバイス",
            transport: .other, hasOutput: true, hasInput: false
        )
        let endpoints = BluetoothEndpointMatch.endpoints(for: Self.registeredAddress, in: [device])
        #expect(endpoints.output == nil)
    }
}
