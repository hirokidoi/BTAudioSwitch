struct Endpoints: Equatable {
    var output: String?
    var input: String?

    var isConnected: Bool { output != nil || input != nil }

    subscript(direction: Direction) -> String? {
        switch direction {
        case .output: output
        case .input: input
        }
    }
}

enum EndpointChange: Equatable {
    case appeared(uid: String)
    case vanished
}

extension EndpointChange {
    static func between(_ old: String?, _ new: String?) -> EndpointChange? {
        guard let new else { return old == nil ? nil : .vanished }
        return old == new ? nil : .appeared(uid: new)
    }
}
