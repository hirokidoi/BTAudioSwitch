enum BluetoothEndpointMatch {
    static func endpoints(for address: String, in devices: [AudioDevice]) -> Endpoints {
        var result = Endpoints()
        for device in devices {
            guard device.transport == .bluetooth || device.transport == .bluetoothLE else { continue }
            guard BluetoothAddress.canonical(device.uid).contains(address) else { continue }
            if device.hasOutput { result.output = device.uid }
            if device.hasInput { result.input = device.uid }
        }
        return result
    }
}
