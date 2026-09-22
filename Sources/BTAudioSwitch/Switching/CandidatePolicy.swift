enum CandidatePolicy {
    static func isCandidate(_ device: AudioDevice, for direction: Direction) -> Bool {
        switch direction {
        case .output:
            device.hasOutput && device.transport != .airPlay
        case .input:
            device.hasInput
        }
    }

    static func candidatesToAdd(
        from devices: [AudioDevice], for direction: Direction, excludingUID excludedUID: String?, listed: [DeviceRef]
    ) -> [AudioDevice] {
        devices.filter { device in
            isCandidate(device, for: direction)
                && device.uid != excludedUID
                && !listed.contains { $0.uid == device.uid }
        }
    }
}
