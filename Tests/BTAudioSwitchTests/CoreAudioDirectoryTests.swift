import AudioToolbox
import CoreAudio
import Testing
@testable import BTAudioSwitch

@Suite("CoreAudioDirectory (実機)")
struct CoreAudioDirectoryTests {
    @Test("1 件以上のデバイスを返す")
    func returnsAtLeastOneDevice() {
        #expect(!CoreAudioDirectory().devices().isEmpty)
    }

    @Test("全件で UID が空でない")
    func allDevicesHaveNonEmptyUID() {
        for device in CoreAudioDirectory().devices() {
            #expect(!device.uid.isEmpty)
        }
    }

    @Test("既定出力デバイスが一覧に含まれ、hasOutput である")
    func defaultOutputDeviceIsListedAndHasOutput() throws {
        let uid = try #require(Self.currentDefaultOutputUID())
        let devices = CoreAudioDirectory().devices()
        let match = try #require(devices.first { $0.uid == uid })
        #expect(match.hasOutput)
    }

    private static func currentDefaultOutputUID() -> String? {
        var deviceID = AudioDeviceID(0)
        var deviceAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &deviceAddress, 0, nil, &deviceSize, &deviceID
        ) == noErr else { return nil }

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid) == noErr else { return nil }
        return uid?.takeRetainedValue() as String?
    }
}
