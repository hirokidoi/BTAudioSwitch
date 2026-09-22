import ServiceManagement
import os

enum LoginItemStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
}

enum LoginItem {
    private static let logger = Logger(subsystem: BundleInfo.subsystem, category: "loginItem")

    static var status: LoginItemStatus {
        status(for: SMAppService.mainApp.status)
    }

    static func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            logger.error("setEnabled(\(enabled, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
        }
        if enabled && service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func status(for status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        default: .notRegistered
        }
    }
}
