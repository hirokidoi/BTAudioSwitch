import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DevicePriorityList: View {
    @Binding var list: [DeviceRef]
    let devices: [AudioDevice]
    let direction: Direction
    let excludedUID: String?

    @State private var selection: String?
    @State private var rowMidYs: [String: CGFloat] = [:]
    @State private var insertionIndex: Int?
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appearsActive) private var appearsActive

    private nonisolated static let rowsCoordinateSpace = "rows"
    private let kindColumnWidth: CGFloat = 185
    private let cellHorizontalPadding: CGFloat = 10
    private let headerHeight: CGFloat = 26
    private let rowVerticalPadding: CGFloat = 4
    private let minimumVisibleRows = 3
    private let bottomBarHeight: CGFloat = 24
    private let addRemoveButtonSize = CGSize(width: 26, height: 22)
    private let separatorThickness: CGFloat = 1
    private let insertionLineHeight: CGFloat = 2
    private let cornerRadius: CGFloat = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("上にあるものほど優先します。行をドラッグして並べ替えます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                header
                rowsArea
                Divider()
                bottomBar
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color(nsColor: .separatorColor)))
        }
    }

    private struct Row: Identifiable {
        let id: String
        let name: String
        let kind: String
        let isAbsent: Bool
    }

    private var rows: [Row] {
        list.map { ref in
            let device = devices.first { $0.uid == ref.uid }
            return Row(
                id: ref.uid,
                name: device?.name ?? ref.name,
                kind: device?.transport.displayName ?? "未接続",
                isAbsent: device == nil
            )
        }
    }

    private func columns(name: some View, kind: some View, showsColumnDivider: Bool = false) -> some View {
        HStack(spacing: 0) {
            name
                .padding(.horizontal, cellHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            kind
                .padding(.horizontal, cellHorizontalPadding)
                .frame(width: kindColumnWidth, alignment: .leading)
                .overlay(alignment: .leading) {
                    if showsColumnDivider { separatorLine(.vertical) }
                }
        }
        .lineLimit(1)
    }

    private var header: some View {
        columns(name: Text("名前"), kind: Text("種類"), showsColumnDivider: true)
            .font(.subheadline)
            .frame(height: headerHeight)
            .background(Color(nsColor: .quaternarySystemFill))
            .overlay(alignment: .bottom) { separatorLine(.horizontal) }
    }

    private var rowsArea: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                dragSource(rowView(row, at: index), uid: row.id)
            }
            ForEach(rows.count..<max(rows.count, minimumVisibleRows), id: \.self) { _ in
                fillerRow
            }
        }
        .coordinateSpace(.named(Self.rowsCoordinateSpace))
        .overlay {
            if list.isEmpty {
                Text("\(noun)がありません。＋ で追加します")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onDrop(of: [.utf8PlainText], delegate: ReorderDropDelegate(
            isEnabled: isEnabled,
            rowMidYs: list.map { rowMidYs[$0.uid] ?? .greatestFiniteMagnitude },
            insertionIndex: $insertionIndex,
            onDrop: { uid, index in move([uid], to: index) }
        ))
        .focusable(isEnabled, interactions: .edit)
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) { moveSelection(by: -1) }
        .onKeyPress(.downArrow) { moveSelection(by: 1) }
        .onDeleteCommand {
            if isEnabled { removeSelected() }
        }
    }

    private func rowView(_ row: Row, at index: Int) -> some View {
        let isSelected = row.id == selection
        let isEmphasized = isSelected && isFocused && appearsActive
        let selectedTextColor = Color(nsColor: .alternateSelectedControlTextColor)
        return columns(
            name: Text(row.name).foregroundStyle(isEmphasized ? selectedTextColor : row.isAbsent ? .secondary : .primary),
            kind: Text(row.kind).foregroundStyle(isEmphasized ? selectedTextColor : .secondary)
        )
        .padding(.vertical, rowVerticalPadding)
        .background(rowBackground(at: index, isSelected: isSelected, isEmphasized: isEmphasized))
        .overlay(alignment: .top) {
            if insertionIndex == index { insertionLine }
        }
        .overlay(alignment: .bottom) {
            if insertionIndex == rows.count, index == rows.count - 1 { insertionLine }
        }
        .contentShape(Rectangle())
        .onTapGesture { select(row.id) }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.frame(in: .named(Self.rowsCoordinateSpace)).midY
        } action: { midY in
            rowMidYs[row.id] = midY
        }
    }

    private var fillerRow: some View {
        columns(name: Text(" "), kind: Text(" "))
            .padding(.vertical, rowVerticalPadding)
            .background(Color(nsColor: .controlBackgroundColor))
            .contentShape(Rectangle())
            .onTapGesture { select(nil) }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func dragSource(_ content: some View, uid: String) -> some View {
        if isEnabled {
            content.onDrag { NSItemProvider(object: uid as NSString) }
        } else {
            content
        }
    }

    private func separatorLine(_ axis: Axis) -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(
                width: axis == .vertical ? separatorThickness : nil,
                height: axis == .horizontal ? separatorThickness : nil
            )
    }

    private var insertionLine: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(height: insertionLineHeight)
    }

    private func rowBackground(at index: Int, isSelected: Bool, isEmphasized: Bool) -> Color {
        if isEmphasized { return Color(nsColor: .selectedContentBackgroundColor) }
        if isSelected { return Color(nsColor: .systemFill) }
        return index.isMultiple(of: 2) ? .clear : Color(nsColor: .quaternarySystemFill)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Menu {
                Section("\(noun)を追加") {
                    ForEach(candidatesToAdd, id: \.uid) { candidate in
                        Button { add(candidate) } label: {
                            Text(candidate.name)
                            Text(candidate.transport.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: addRemoveButtonSize.width, height: addRemoveButtonSize.height)
            .disabled(candidatesToAdd.isEmpty)
            .help("\(noun)を追加")
            Button { removeSelected() } label: {
                Image(systemName: "minus").frame(width: addRemoveButtonSize.width, height: addRemoveButtonSize.height)
            }
            .buttonStyle(.borderless)
            .disabled(selectedIndex == nil)
            .help("選択した\(noun)を削除")
            Spacer()
        }
        .frame(height: bottomBarHeight)
    }

    private var noun: String {
        direction == .output ? "出力先" : "入力先"
    }

    private var candidatesToAdd: [AudioDevice] {
        CandidatePolicy.candidatesToAdd(from: devices, for: direction, excludingUID: excludedUID, listed: list)
    }

    private var selectedIndex: Int? {
        guard let selection else { return nil }
        return list.firstIndex { $0.uid == selection }
    }

    private func select(_ uid: String?) {
        guard isEnabled else { return }
        selection = uid
        isFocused = true
    }

    private func moveSelection(by step: Int) -> KeyPress.Result {
        guard isEnabled, !list.isEmpty else { return .ignored }
        let next = selectedIndex.map { $0 + step } ?? (step > 0 ? 0 : list.count - 1)
        selection = list[min(max(next, 0), list.count - 1)].uid
        return .handled
    }

    private func add(_ device: AudioDevice) {
        list.append(DeviceRef(uid: device.uid, name: device.name))
        selection = device.uid
    }

    private func removeSelected() {
        guard let index = selectedIndex else { return }
        list.remove(at: index)
        selection = list.indices.contains(index) ? list[index].uid : list.last?.uid
    }

    private func move(_ uids: [String], to index: Int) {
        guard let moved = PriorityListReorder.moving(uids, in: list, to: index) else { return }
        list = moved
        selection = uids.first
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let isEnabled: Bool
    let rowMidYs: [CGFloat]
    @Binding var insertionIndex: Int?
    let onDrop: @MainActor @Sendable (String, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && info.hasItemsConforming(to: [.utf8PlainText])
    }

    func dropEntered(info: DropInfo) {
        insertionIndex = index(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        insertionIndex = index(for: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        insertionIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        let index = index(for: info)
        insertionIndex = nil
        guard let provider = info.itemProviders(for: [.utf8PlainText]).first else { return false }
        let onDrop = onDrop
        _ = provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let uid = object as? NSString else { return }
            let value = uid as String
            Task { @MainActor in onDrop(value, index) }
        }
        return true
    }

    private func index(for info: DropInfo) -> Int {
        PriorityListReorder.insertionIndex(at: info.location.y, rowMidYs: rowMidYs)
    }
}
