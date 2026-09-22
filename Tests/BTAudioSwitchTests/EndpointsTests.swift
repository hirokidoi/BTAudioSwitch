import Testing
@testable import BTAudioSwitch

@Suite("エンドポイントの変化")
struct EndpointsTests {
    @Test("無いまま無いは変化なし")
    func nilToNilIsNoChange() {
        #expect(EndpointChange.between(nil, nil) == nil)
    }

    @Test("無いから出るのは出現")
    func nilToValueIsAppeared() {
        #expect(EndpointChange.between(nil, "uid-a") == .appeared(uid: "uid-a"))
    }

    @Test("あるものが無くなるのは消失")
    func valueToNilIsVanished() {
        #expect(EndpointChange.between("uid-a", nil) == .vanished)
    }

    @Test("同じ値のままは変化なし")
    func sameValueIsNoChange() {
        #expect(EndpointChange.between("uid-a", "uid-a") == nil)
    }

    @Test("別の値に入れ替わるのは新しい方の出現")
    func differentValueIsAppearedOfNewUID() {
        #expect(EndpointChange.between("uid-a", "uid-b") == .appeared(uid: "uid-b"))
    }
}
