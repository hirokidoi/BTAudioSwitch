import Testing
@testable import BTAudioSwitch

@Suite("対象の機器の候補")
struct DeviceChoicesTests {
    private static let audioDevice = PairedDevice(address: "0A:1B:2C:3D:4E:5F", name: "Headphone X2", isAudio: true)
    private static let nonAudioDevice = PairedDevice(address: "1A:2B:3C:4D:5E:6F", name: "Keyboard", isAudio: false)

    @Test("オーディオ機器でない機器は除く")
    func excludesNonAudioDevices() {
        let choices = DeviceChoices.make(paired: [Self.audioDevice, Self.nonAudioDevice], registered: nil)
        #expect(choices == [RegisteredDevice(address: Self.audioDevice.address, name: Self.audioDevice.name)])
    }

    @Test("登録済みの機器はペアリング一覧に無くても残る")
    func keepsRegisteredDeviceAbsentFromPairedList() {
        let registered = RegisteredDevice(address: "2A:3B:4C:5D:6E:7F", name: "Old Headphone")
        let choices = DeviceChoices.make(paired: [Self.audioDevice], registered: registered)
        #expect(choices == [
            RegisteredDevice(address: Self.audioDevice.address, name: Self.audioDevice.name),
            registered,
        ])
    }

    @Test("登録済みの機器はオーディオ機器でなくても残る")
    func keepsRegisteredDeviceEvenIfNotAudio() {
        let registered = RegisteredDevice(address: Self.nonAudioDevice.address, name: Self.nonAudioDevice.name)
        let choices = DeviceChoices.make(paired: [Self.audioDevice, Self.nonAudioDevice], registered: registered)
        #expect(choices == [
            RegisteredDevice(address: Self.audioDevice.address, name: Self.audioDevice.name),
            registered,
        ])
    }

    @Test("登録済みの機器がペアリング一覧のオーディオ機器と同じなら重複しない")
    func doesNotDuplicateRegisteredDevice() {
        let registered = RegisteredDevice(address: Self.audioDevice.address, name: Self.audioDevice.name)
        let choices = DeviceChoices.make(paired: [Self.audioDevice], registered: registered)
        #expect(choices == [registered])
    }
}
