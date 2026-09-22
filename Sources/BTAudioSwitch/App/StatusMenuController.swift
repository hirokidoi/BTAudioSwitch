import AppKit
import Observation

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    // 設計値: 未起動の .app からでもメニューに届けられるだけの猶予
    private static let startupGraceDuration: Duration = .seconds(15)

    private static let disconnectedIconAlpha: CGFloat = 0.6
    private let statusItem: NSStatusItem
    private let coordinator: SwitchCoordinator
    private let settingsStore: SettingsStore
    private let settingsWindowController: SettingsWindowController
    private let batteryMonitor: BatteryMonitor
    private lazy var aboutWindowController = AboutWindowController()
    private let menu = NSMenu()
    private var lastConnectedAddress: String?
    private var deviceItem: NSMenuItem!
    private var batteryItem: NSMenuItem!
    private var isWithinStartupGrace = true

    init(
        coordinator: SwitchCoordinator,
        settingsStore: SettingsStore,
        settingsWindowController: SettingsWindowController,
        batteryMonitor: BatteryMonitor
    ) {
        self.coordinator = coordinator
        self.settingsStore = settingsStore
        self.settingsWindowController = settingsWindowController
        self.batteryMonitor = batteryMonitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        let image = NSImage(systemSymbolName: "headphones.dots", accessibilityDescription: BundleInfo.productName)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .regular))
        image?.isTemplate = true
        statusItem.button?.image = image

        buildMenu()
        menu.delegate = self
        statusItem.menu = menu

        observeState()
        scheduleStartupGraceEnd()
    }

    private func scheduleStartupGraceEnd() {
        Task { [weak self] in
            try? await Task.sleep(for: Self.startupGraceDuration)
            guard let self else { return }
            isWithinStartupGrace = false
            updateVisibility()
        }
    }

    private func buildMenu() {
        let device = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        device.target = self
        menu.addItem(device)
        deviceItem = device

        let battery = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(battery)
        batteryItem = battery

        menu.addItem(.separator())

        // openSettings のような名前だと OS が標準の設定コマンドと見なして歯車アイコンを付ける
        let settings = NSMenuItem(title: "Settings", action: #selector(openSettingsWindow), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: "About \(BundleInfo.productName)", action: #selector(openAboutWindow), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        coordinator.syncRegisteredDeviceName()
        batteryItem.isHidden = !coordinator.isRegisteredDeviceConnected
        guard let device = settingsStore.settings.registeredDevice else {
            deviceItem.title = "(機器が登録されていません)"
            deviceItem.action = nil
            deviceItem.isEnabled = false
            return
        }
        switch coordinator.pendingOperation {
        case .connecting:
            deviceItem.title = "\(device.name) に接続中…"
            deviceItem.action = nil
            deviceItem.isEnabled = false
        case .disconnecting:
            deviceItem.title = "\(device.name) を切断中…"
            deviceItem.action = nil
            deviceItem.isEnabled = false
        case nil:
            if coordinator.isRegisteredDeviceConnected {
                deviceItem.title = "\(device.name) を切断"
                deviceItem.action = #selector(disconnect)
            } else {
                deviceItem.title = "\(device.name) に接続"
                deviceItem.action = #selector(connect)
            }
            deviceItem.isEnabled = true
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard coordinator.isRegisteredDeviceConnected else { return }
        Task { await batteryMonitor.refresh() }
    }

    private func refreshBatteryOnConnection() {
        let connectedAddress = coordinator.isRegisteredDeviceConnected ? settingsStore.settings.registeredDevice?.address : nil
        defer { lastConnectedAddress = connectedAddress }
        guard let connectedAddress, connectedAddress != lastConnectedAddress else { return }
        Task { await batteryMonitor.refresh() }
    }

    private func updateBatteryItem() {
        batteryItem.title = "Battery: \(BatteryIndicator.text(for: batteryMonitor.level))"
    }

    private func updateVisibility() {
        statusItem.isVisible = settingsStore.settings.iconVisibility.showsIcon(
            isConnected: coordinator.isRegisteredDeviceConnected,
            isSettingsOpen: settingsWindowController.isOpen,
            isWithinStartupGrace: isWithinStartupGrace
        )
    }

    private func updateIconAppearance() {
        statusItem.button?.alphaValue = coordinator.isRegisteredDeviceConnected ? 1 : Self.disconnectedIconAlpha
    }

    private func observeState() {
        withObservationTracking {
            updateVisibility()
            updateIconAppearance()
            updateBatteryItem()
            refreshBatteryOnConnection()
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.observeState() }
        }
    }

    @objc private func connect() {
        Task { await coordinator.connect() }
    }

    @objc private func disconnect() {
        Task { await coordinator.disconnect() }
    }

    @objc private func openSettingsWindow() {
        settingsWindowController.show()
    }

    @objc private func openAboutWindow() {
        aboutWindowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
