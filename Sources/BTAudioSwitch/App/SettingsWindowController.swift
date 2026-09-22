import AppKit
import SwiftUI

@MainActor
@Observable
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let windowWidth: CGFloat = 640
    private static let maxWindowHeight: CGFloat = 1000

    private(set) var isOpen = false

    init(coordinator: SwitchCoordinator, settingsStore: SettingsStore, bluetooth: any BluetoothDirectory, batteryMonitor: BatteryMonitor) {
        let window = NSWindow()
        window.title = "\(BundleInfo.productName) Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let view = SettingsView(
            coordinator: coordinator,
            settingsStore: settingsStore,
            bluetooth: bluetooth,
            batteryMonitor: batteryMonitor,
            settingsWindowController: self
        )
        let hostingController = NSHostingController(rootView: view)
        hostingController.sizingOptions = []
        window.contentViewController = hostingController
        let size = NSSize(width: Self.windowWidth, height: Self.height(fittingIn: NSScreen.main))
        window.setFrame(NSRect(origin: .zero, size: size), display: false)
        window.center()
        window.delegate = self
    }

    private static func height(fittingIn screen: NSScreen?) -> CGFloat {
        guard let screen else { return maxWindowHeight }
        return min(maxWindowHeight, screen.visibleFrame.height)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        isOpen = true
    }

    func windowWillClose(_ notification: Notification) {
        isOpen = false
    }
}
