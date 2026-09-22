import Testing
@testable import BTAudioSwitch

@Suite("BT アドレスの正規化")
struct BluetoothAddressTests {
    @Test("表記の揺れが同じ正規形になる")
    func normalizesNotationVariants() {
        let expected = "0A:1B:2C:3D:4E:5F"
        #expect(BluetoothAddress.canonical("0A:1B:2C:3D:4E:5F") == expected)
        #expect(BluetoothAddress.canonical("0a:1b:2c:3d:4e:5f") == expected)
        #expect(BluetoothAddress.canonical("0A-1B-2C-3D-4E-5F") == expected)
        #expect(BluetoothAddress.canonical("0a-1b-2c-3d-4e-5f") == expected)
    }
}
