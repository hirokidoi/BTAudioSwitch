struct PairedDevice: Equatable {
    let address: String
    let name: String
    let isAudio: Bool
}

enum BluetoothAddress {
    static func canonical(_ raw: String) -> String {
        raw.uppercased().replacingOccurrences(of: "-", with: ":")
    }
}

protocol BluetoothDirectory: Sendable {
    func pairedDevices() -> [PairedDevice]
    func connect(address: String) async -> Bool
    func disconnect(address: String) async -> Bool
}
