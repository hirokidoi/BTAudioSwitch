import Foundation
import Testing
@testable import BTAudioSwitch

@Suite("優先度リストの並べ替え")
struct PriorityListReorderTests {
    private static let rowMidYs: [CGFloat] = [10, 30, 50]
    private static let list = ["a", "b", "c"].map { DeviceRef(uid: $0, name: $0) }

    private func uids(_ list: [DeviceRef]?) -> [String]? {
        list?.map(\.uid)
    }

    @Test("行の上半分なら前に、下半分なら後ろに入れる")
    func insertsBeforeUpperHalfAndAfterLowerHalf() {
        #expect(PriorityListReorder.insertionIndex(at: 25, rowMidYs: Self.rowMidYs) == 1)
        #expect(PriorityListReorder.insertionIndex(at: 35, rowMidYs: Self.rowMidYs) == 2)
    }

    @Test("先頭の行の上半分なら先頭の前、末尾の行の下半分なら末尾の後ろ")
    func insertsAtBothEnds() {
        #expect(PriorityListReorder.insertionIndex(at: 0, rowMidYs: Self.rowMidYs) == 0)
        #expect(PriorityListReorder.insertionIndex(at: 55, rowMidYs: Self.rowMidYs) == Self.rowMidYs.count)
    }

    @Test("行の下の空き (最低行数を埋める空行) に落としたら末尾に入れる")
    func insertsAtEndWhenDroppedBelowRows() {
        #expect(PriorityListReorder.insertionIndex(at: 1000, rowMidYs: Self.rowMidYs) == Self.rowMidYs.count)
    }

    @Test("自分の行へ落としても順番は変わらない")
    func droppingOnOwnRowKeepsOrder() {
        for y: CGFloat in [25, 35] {
            let index = PriorityListReorder.insertionIndex(at: y, rowMidYs: Self.rowMidYs)
            #expect(uids(PriorityListReorder.moving(["b"], in: Self.list, to: index)) == ["a", "b", "c"])
        }
    }

    @Test("先頭の前・末尾の後ろへ動かせる")
    func movesToBothEnds() {
        #expect(uids(PriorityListReorder.moving(["c"], in: Self.list, to: 0)) == ["c", "a", "b"])
        #expect(uids(PriorityListReorder.moving(["a"], in: Self.list, to: Self.list.count)) == ["b", "c", "a"])
    }

    @Test("複数件を元の並びのまま動かせる")
    func movesMultipleItemsKeepingTheirOrder() {
        let list = ["a", "b", "c", "d"].map { DeviceRef(uid: $0, name: $0) }
        #expect(uids(PriorityListReorder.moving(["c", "a"], in: list, to: list.count)) == ["b", "d", "a", "c"])
        #expect(uids(PriorityListReorder.moving(["a", "c"], in: list, to: 2)) == ["b", "a", "c", "d"])
    }

    @Test("一覧に無いものだけなら動かさない")
    func ignoresUnknownItems() {
        #expect(PriorityListReorder.moving(["x"], in: Self.list, to: 0) == nil)
    }
}
