import SwiftUI

struct BatteryIndicator: View {
    let level: Int?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: Self.symbolName(for: level))
            Text(Self.text(for: level))
        }
        .foregroundStyle(.secondary)
    }

    static func symbolName(for level: Int?) -> String {
        let step = 25
        let clamped = min(max(level ?? 0, 0), 100)
        let rounded = (clamped + step / 2) / step * step
        return "battery.\(rounded)percent"
    }

    static func text(for level: Int?) -> String {
        level.map { "\($0)%" } ?? "---"
    }
}
