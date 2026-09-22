enum DeviceChoices {
    static func make(paired: [PairedDevice], registered: RegisteredDevice?) -> [RegisteredDevice] {
        var choices = paired.filter(\.isAudio).map { RegisteredDevice(address: $0.address, name: $0.name) }
        if let registered, !choices.contains(where: { $0.address == registered.address }) {
            choices.append(registered)
        }
        return choices
    }
}
