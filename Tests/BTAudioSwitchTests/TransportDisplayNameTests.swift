import Testing
@testable import BTAudioSwitch

@Suite("転送種別の表示名")
struct TransportDisplayNameTests {
    @Test("Bluetooth と Bluetooth LE は同じ表示にする")
    func bluetoothVariantsShareDisplayName() {
        #expect(Transport.bluetooth.displayName == Transport.bluetoothLE.displayName)
    }

    @Test("AirPlay は未知の種別と同じ表示にする")
    func airPlaySharesDisplayNameWithUnknown() {
        #expect(Transport.airPlay.displayName == Transport.other.displayName)
    }
}
