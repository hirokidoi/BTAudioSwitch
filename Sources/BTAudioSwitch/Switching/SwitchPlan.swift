struct DefaultWrite: Equatable {
    let direction: Direction
    let uid: String
}

enum SwitchPlan {
    static func make(old: Endpoints, new: Endpoints, settings: AppSettings, devices: [AudioDevice]) -> [DefaultWrite] {
        Direction.allCases.compactMap { direction in
            guard direction == .output || settings.switchesInput else { return nil }
            return planWrite(direction: direction, old: old[direction], new: new[direction], settings: settings, devices: devices)
        }
    }

    private static func planWrite(
        direction: Direction, old: String?, new: String?, settings: AppSettings, devices: [AudioDevice]
    ) -> DefaultWrite? {
        switch EndpointChange.between(old, new) {
        case nil:
            return nil
        case .appeared(let uid):
            return DefaultWrite(direction: direction, uid: uid)
        case .vanished:
            guard let uid = fallbackTarget(direction: direction, settings: settings, devices: devices) else { return nil }
            return DefaultWrite(direction: direction, uid: uid)
        }
    }

    private static func fallbackTarget(direction: Direction, settings: AppSettings, devices: [AudioDevice]) -> String? {
        let list: [DeviceRef]
        switch direction {
        case .output:
            guard settings.outputFallbackMode == .priorityList else { return nil }
            list = settings.outputFallback
        case .input:
            guard settings.inputFallbackMode == .priorityList else { return nil }
            list = settings.inputFallback
        }
        return list.first { ref in
            devices.contains { $0.uid == ref.uid && CandidatePolicy.isCandidate($0, for: direction) }
        }?.uid
    }
}
