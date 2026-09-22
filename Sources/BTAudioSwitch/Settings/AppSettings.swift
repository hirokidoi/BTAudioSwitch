struct RegisteredDevice: Codable, Equatable {
    var address: String
    var name: String
}

struct DeviceRef: Codable, Equatable {
    var uid: String
    var name: String
}

enum FallbackMode: String, Codable {
    case automatic
    case priorityList
}

enum IconVisibility: String, Codable {
    case always
    case whileConnected

    func showsIcon(isConnected: Bool, isSettingsOpen: Bool, isWithinStartupGrace: Bool) -> Bool {
        self == .always || isConnected || isSettingsOpen || isWithinStartupGrace
    }
}

struct AppSettings: Codable, Equatable {
    var registeredDevice: RegisteredDevice?
    var outputFallbackMode: FallbackMode = .automatic
    var outputFallback: [DeviceRef] = []
    var switchesInput: Bool = false
    var inputFallbackMode: FallbackMode = .automatic
    var inputFallback: [DeviceRef] = []
    var iconVisibility: IconVisibility = .always

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self()
        registeredDevice = try container.decodeIfPresent(RegisteredDevice.self, forKey: .registeredDevice) ?? defaults.registeredDevice
        outputFallbackMode = try container.decodeIfPresent(FallbackMode.self, forKey: .outputFallbackMode) ?? defaults.outputFallbackMode
        outputFallback = try container.decodeIfPresent([DeviceRef].self, forKey: .outputFallback) ?? defaults.outputFallback
        switchesInput = try container.decodeIfPresent(Bool.self, forKey: .switchesInput) ?? defaults.switchesInput
        inputFallbackMode = try container.decodeIfPresent(FallbackMode.self, forKey: .inputFallbackMode) ?? defaults.inputFallbackMode
        inputFallback = try container.decodeIfPresent([DeviceRef].self, forKey: .inputFallback) ?? defaults.inputFallback
        iconVisibility = try container.decodeIfPresent(IconVisibility.self, forKey: .iconVisibility) ?? defaults.iconVisibility
    }
}
