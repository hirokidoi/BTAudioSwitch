import Testing
@testable import BTAudioSwitch

@Suite("候補の基準")
struct CandidatePolicyTests {
    private func device(
        uid: String = "uid", transport: Transport, hasOutput: Bool = false, hasInput: Bool = false
    ) -> AudioDevice {
        AudioDevice(uid: uid, name: "device", transport: transport, hasOutput: hasOutput, hasInput: hasInput)
    }

    @Test("出力候補は AirPlay だけを外す")
    func outputExcludesOnlyAirPlay() {
        #expect(CandidatePolicy.isCandidate(device(transport: .bluetooth, hasOutput: true), for: .output))
        #expect(CandidatePolicy.isCandidate(device(transport: .virtual, hasOutput: true), for: .output))
        #expect(CandidatePolicy.isCandidate(device(transport: .aggregate, hasOutput: true), for: .output))
        #expect(CandidatePolicy.isCandidate(device(transport: .other, hasOutput: true), for: .output))
        #expect(!CandidatePolicy.isCandidate(device(transport: .airPlay, hasOutput: true), for: .output))
    }

    @Test("出力ストリームが無ければ転送種別によらず候補にならない")
    func outputRequiresOutputStream() {
        #expect(!CandidatePolicy.isCandidate(device(transport: .bluetooth, hasOutput: false), for: .output))
    }

    @Test("入力候補はストリームの有無だけで決まる")
    func inputDependsOnlyOnStream() {
        #expect(CandidatePolicy.isCandidate(device(transport: .airPlay, hasInput: true), for: .input))
        #expect(CandidatePolicy.isCandidate(device(transport: .bluetooth, hasInput: true), for: .input))
        #expect(!CandidatePolicy.isCandidate(device(transport: .bluetooth, hasInput: false), for: .input))
    }

    @Test("追加候補は方向の候補だけに絞る")
    func candidatesToAddFollowDirectionPolicy() {
        let speaker = device(uid: "speaker", transport: .builtIn, hasOutput: true)
        let airPlay = device(uid: "airplay", transport: .airPlay, hasOutput: true)
        let mic = device(uid: "mic", transport: .usb, hasInput: true)
        let candidates = CandidatePolicy.candidatesToAdd(
            from: [speaker, airPlay, mic], for: .output, excludingUID: nil, listed: []
        )
        #expect(candidates == [speaker])
    }

    @Test("追加候補から登録機器自身のエンドポイントを外す")
    func candidatesToAddExcludeRegisteredEndpoint() {
        let registered = device(uid: "registered", transport: .bluetooth, hasOutput: true)
        let speaker = device(uid: "speaker", transport: .builtIn, hasOutput: true)
        let candidates = CandidatePolicy.candidatesToAdd(
            from: [registered, speaker], for: .output, excludingUID: registered.uid, listed: []
        )
        #expect(candidates == [speaker])
    }

    @Test("追加候補から追加済みのものを外す")
    func candidatesToAddExcludeListedDevices() {
        let speaker = device(uid: "speaker", transport: .builtIn, hasOutput: true)
        let usb = device(uid: "usb", transport: .usb, hasOutput: true)
        let candidates = CandidatePolicy.candidatesToAdd(
            from: [speaker, usb], for: .output, excludingUID: nil, listed: [DeviceRef(uid: speaker.uid, name: "スピーカー")]
        )
        #expect(candidates == [usb])
    }
}
