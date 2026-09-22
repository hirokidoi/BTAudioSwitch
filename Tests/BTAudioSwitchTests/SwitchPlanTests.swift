import Testing
@testable import BTAudioSwitch

@Suite("切替計画")
struct SwitchPlanTests {
    private func device(
        uid: String, transport: Transport = .bluetooth, hasOutput: Bool = false, hasInput: Bool = false
    ) -> AudioDevice {
        AudioDevice(uid: uid, name: uid, transport: transport, hasOutput: hasOutput, hasInput: hasInput)
    }

    private func settings(
        outputFallbackMode: FallbackMode = .priorityList,
        outputFallback: [DeviceRef] = [],
        switchesInput: Bool = false,
        inputFallbackMode: FallbackMode = .automatic,
        inputFallback: [DeviceRef] = []
    ) -> AppSettings {
        var settings = AppSettings()
        settings.outputFallbackMode = outputFallbackMode
        settings.outputFallback = outputFallback
        settings.switchesInput = switchesInput
        settings.inputFallbackMode = inputFallbackMode
        settings.inputFallback = inputFallback
        return settings
    }

    // MARK: - 出現

    @Test("出力の出現は出力を書く")
    func outputAppearanceWritesOutput() {
        let writes = SwitchPlan.make(
            old: Endpoints(), new: Endpoints(output: "out-uid"), settings: settings(), devices: []
        )
        #expect(writes == [DefaultWrite(direction: .output, uid: "out-uid")])
    }

    @Test("入力切替が OFF なら入力が現れても書かない")
    func inputAppearanceIsIgnoredWhenSwitchingIsOff() {
        let writes = SwitchPlan.make(
            old: Endpoints(), new: Endpoints(input: "in-uid"),
            settings: settings(switchesInput: false), devices: []
        )
        #expect(writes.isEmpty)
    }

    @Test("入力切替が ON なら入力の出現も書く")
    func inputAppearanceWritesInputWhenSwitchingIsOn() {
        let writes = SwitchPlan.make(
            old: Endpoints(), new: Endpoints(input: "in-uid"),
            settings: settings(switchesInput: true), devices: []
        )
        #expect(writes == [DefaultWrite(direction: .input, uid: "in-uid")])
    }

    @Test("UID が入れ替わったら新しい UID を 1 回だけ書く")
    func uidSwapWritesNewUIDOnce() {
        let writes = SwitchPlan.make(
            old: Endpoints(output: "old-uid"), new: Endpoints(output: "new-uid"),
            settings: settings(), devices: []
        )
        #expect(writes == [DefaultWrite(direction: .output, uid: "new-uid")])
    }

    // MARK: - 消失・出力フォールバック

    @Test("出力の消失はフォールバック先頭の候補を書く")
    func outputVanishingWritesFirstAvailableFallback() {
        let devices = [device(uid: "uid-2", hasOutput: true)]
        let writes = SwitchPlan.make(
            old: Endpoints(output: "gone-uid"), new: Endpoints(),
            settings: settings(outputFallback: [
                DeviceRef(uid: "uid-1", name: "不在"), DeviceRef(uid: "uid-2", name: "候補"),
            ]),
            devices: devices
        )
        #expect(writes == [DefaultWrite(direction: .output, uid: "uid-2")])
    }

    @Test("出力フォールバックは AirPlay を飛ばす")
    func outputFallbackSkipsAirPlay() {
        let devices = [
            device(uid: "uid-airplay", transport: .airPlay, hasOutput: true),
            device(uid: "uid-ok", hasOutput: true),
        ]
        let writes = SwitchPlan.make(
            old: Endpoints(output: "gone-uid"), new: Endpoints(),
            settings: settings(outputFallback: [
                DeviceRef(uid: "uid-airplay", name: "AirPlay"), DeviceRef(uid: "uid-ok", name: "候補"),
            ]),
            devices: devices
        )
        #expect(writes == [DefaultWrite(direction: .output, uid: "uid-ok")])
    }

    @Test("仮想・集約デバイスは飛ばさない")
    func outputFallbackDoesNotSkipVirtualOrAggregate() {
        for transport in [Transport.virtual, .aggregate] {
            let writes = SwitchPlan.make(
                old: Endpoints(output: "gone-uid"), new: Endpoints(),
                settings: settings(outputFallback: [DeviceRef(uid: "uid-1", name: "候補")]),
                devices: [device(uid: "uid-1", transport: transport, hasOutput: true)]
            )
            #expect(writes == [DefaultWrite(direction: .output, uid: "uid-1")])
        }
    }

    @Test("出力フォールバック先が全滅なら書かない")
    func outputVanishingWithNoAvailableFallbackWritesNothing() {
        let writes = SwitchPlan.make(
            old: Endpoints(output: "gone-uid"), new: Endpoints(),
            settings: settings(outputFallback: [DeviceRef(uid: "uid-1", name: "不在")]),
            devices: []
        )
        #expect(writes.isEmpty)
    }

    @Test("出力の切断時の方式が自動なら、使えるフォールバック先があっても書かない")
    func outputVanishingInAutomaticModeWritesNothing() {
        let writes = SwitchPlan.make(
            old: Endpoints(output: "gone-uid"), new: Endpoints(),
            settings: settings(
                outputFallbackMode: .automatic,
                outputFallback: [DeviceRef(uid: "uid-1", name: "スピーカー")]
            ),
            devices: [device(uid: "uid-1", hasOutput: true)]
        )
        #expect(writes.isEmpty)
    }

    // MARK: - 消失・入力フォールバック

    @Test("入力切替 ON かつ自動モードでは入力の消失で書かない")
    func inputVanishingWritesNothingInAutomaticMode() {
        let writes = SwitchPlan.make(
            old: Endpoints(input: "gone-uid"), new: Endpoints(),
            settings: settings(switchesInput: true, inputFallbackMode: .automatic),
            devices: [device(uid: "uid-2", hasInput: true)]
        )
        #expect(writes.isEmpty)
    }

    @Test("入力切替 ON かつ優先度リストでは出力と同じ規則で書く")
    func inputVanishingWritesFallbackInPriorityListMode() {
        let devices = [device(uid: "uid-2", hasInput: true)]
        let writes = SwitchPlan.make(
            old: Endpoints(input: "gone-uid"), new: Endpoints(),
            settings: settings(
                switchesInput: true, inputFallbackMode: .priorityList,
                inputFallback: [DeviceRef(uid: "uid-1", name: "不在"), DeviceRef(uid: "uid-2", name: "候補")]
            ),
            devices: devices
        )
        #expect(writes == [DefaultWrite(direction: .input, uid: "uid-2")])
    }

    @Test("入力切替 OFF ならモードによらず入力の消失で書かない")
    func inputVanishingWritesNothingWhenSwitchingIsOff() {
        let writes = SwitchPlan.make(
            old: Endpoints(input: "gone-uid"), new: Endpoints(),
            settings: settings(
                switchesInput: false, inputFallbackMode: .priorityList,
                inputFallback: [DeviceRef(uid: "uid-2", name: "候補")]
            ),
            devices: [device(uid: "uid-2", hasInput: true)]
        )
        #expect(writes.isEmpty)
    }

    // MARK: - 方向ごとに最大 1 件

    @Test("出力と入力が同時に出現しても方向ごとに 1 件ずつになる")
    func bothDirectionsWriteAtMostOnceEach() {
        let writes = SwitchPlan.make(
            old: Endpoints(), new: Endpoints(output: "out-uid", input: "in-uid"),
            settings: settings(switchesInput: true), devices: []
        )
        #expect(writes.count == 2)
        #expect(writes.contains(DefaultWrite(direction: .output, uid: "out-uid")))
        #expect(writes.contains(DefaultWrite(direction: .input, uid: "in-uid")))
    }

    @Test("変化が無ければ書かない")
    func noChangeWritesNothing() {
        let endpoints = Endpoints(output: "same-uid", input: "same-uid-2")
        let writes = SwitchPlan.make(
            old: endpoints, new: endpoints, settings: settings(switchesInput: true), devices: []
        )
        #expect(writes.isEmpty)
    }
}
