import SwiftUI

enum PriorityListReorder {
    static func insertionIndex(at y: CGFloat, rowMidYs: [CGFloat]) -> Int {
        rowMidYs.firstIndex { y < $0 } ?? rowMidYs.count
    }

    static func moving(_ uids: [String], in list: [DeviceRef], to index: Int) -> [DeviceRef]? {
        var list = list
        let offsets = IndexSet(uids.compactMap { uid in list.firstIndex { $0.uid == uid } })
        guard !offsets.isEmpty else { return nil }
        list.move(fromOffsets: offsets, toOffset: index)
        return list
    }
}
