struct AudioDevice: Equatable {
    let uid: String
    let name: String
    let transport: Transport
    let hasOutput: Bool
    let hasInput: Bool
}

enum Transport {
    case builtIn
    case hdmi
    case displayPort
    case usb
    case virtual
    case aggregate
    case bluetooth
    case bluetoothLE
    case airPlay
    case other
}

enum Direction: CaseIterable {
    case output
    case input
}

protocol AudioDeviceDirectory: Sendable {
    func devices() -> [AudioDevice]
    func setDefault(_ direction: Direction, uid: String) -> Bool
    func observeDeviceListChanges(_ handler: @escaping @MainActor @Sendable () -> Void)
}
