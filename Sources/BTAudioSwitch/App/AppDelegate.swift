import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let audio: any AudioDeviceDirectory = CoreAudioDirectory()
    private let bluetooth: any BluetoothDirectory = IOBluetoothDirectory()
    private let settingsStore = SettingsStore()
    private lazy var coordinator = SwitchCoordinator(audio: audio, bluetooth: bluetooth, settingsStore: settingsStore)
    private lazy var batteryMonitor = BatteryMonitor(
        reader: FallbackBatteryReader([IOBluetoothBatteryReader(), SystemProfilerBatteryReader()]),
        settingsStore: settingsStore
    )

    private lazy var settingsWindowController = SettingsWindowController(
        coordinator: coordinator,
        settingsStore: settingsStore,
        bluetooth: bluetooth,
        batteryMonitor: batteryMonitor
    )
    private var statusMenuController: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        coordinator.start()
        statusMenuController = StatusMenuController(
            coordinator: coordinator,
            settingsStore: settingsStore,
            settingsWindowController: settingsWindowController,
            batteryMonitor: batteryMonitor
        )
        if settingsStore.settings.registeredDevice == nil {
            settingsWindowController.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindowController.show()
        return true
    }

    // アクセサリアプリにはメニューバーが無く、設定画面が前面のときの ⌘Q / ⌘W はここでしか受けられない
    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "閉じる", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
