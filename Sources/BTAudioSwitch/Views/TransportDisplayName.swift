extension Transport {
    var displayName: String {
        switch self {
        case .builtIn: "内蔵"
        case .hdmi: "HDMI"
        case .displayPort: "DisplayPort"
        case .usb: "USB"
        case .virtual: "仮想"
        case .aggregate: "集約"
        case .bluetooth, .bluetoothLE: "Bluetooth"
        case .airPlay, .other: "その他"
        }
    }
}
