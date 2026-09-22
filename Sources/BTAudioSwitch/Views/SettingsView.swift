import AppKit
import SwiftUI

struct SettingsView: View {
    private static let disabledOpacity = 0.4

    var coordinator: SwitchCoordinator
    @Bindable var settingsStore: SettingsStore
    let bluetooth: any BluetoothDirectory
    var batteryMonitor: BatteryMonitor
    weak var settingsWindowController: SettingsWindowController?

    @State private var pairedDevices: [PairedDevice] = []
    @State private var loginItemStatus = LoginItem.status

    var body: some View {
        Form {
            deviceSection
            outputFallbackSection
            inputSection
            generalSection
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard notification.object as? NSWindow === settingsWindowController?.window else { return }
            reload()
            loginItemStatus = LoginItem.status
        }
    }

    private func reload() {
        coordinator.syncRegisteredDeviceName()
        pairedDevices = bluetooth.pairedDevices()
        refreshBattery()
    }

    private func refreshBattery() {
        guard coordinator.isRegisteredDeviceConnected else { return }
        Task { await batteryMonitor.refresh() }
    }

    // MARK: - 対象の機器

    private var deviceChoices: [RegisteredDevice] {
        DeviceChoices.make(paired: pairedDevices, registered: settingsStore.settings.registeredDevice)
    }

    private var hasAudioPairedDevice: Bool {
        pairedDevices.contains(where: \.isAudio)
    }

    private var registeredDeviceSelection: Binding<String?> {
        Binding(
            get: { settingsStore.settings.registeredDevice?.address },
            set: { newValue in
                settingsStore.settings.registeredDevice = deviceChoices.first { $0.address == newValue }
            }
        )
    }

    private var deviceSection: some View {
        Section {
            Picker(selection: registeredDeviceSelection) {
                Text("未登録").tag(String?.none)
                ForEach(deviceChoices, id: \.address) { choice in
                    Text(choice.name).tag(String?.some(choice.address))
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "headphones")
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("機器")
                        if let registered = settingsStore.settings.registeredDevice {
                            Text(registered.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if settingsStore.settings.registeredDevice != nil {
                LabeledContent("状態") {
                    connectionStatus
                }
            }
        } header: {
            Text("対象の機器")
        } footer: {
            deviceFooter
        }
    }

    private var connectionStatus: some View {
        let isConnected = coordinator.isRegisteredDeviceConnected
        let pending = coordinator.pendingOperation
        return HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                .frame(width: 8, height: 8)
            Text(connectionStatusText(isConnected: isConnected, pending: pending))
                .foregroundStyle(.secondary)
            if isConnected {
                BatteryIndicator(level: batteryMonitor.level)
                    .padding(.leading, 6)
            }
            Button(isConnected ? "切断" : "接続") {
                Task {
                    if isConnected {
                        await coordinator.disconnect()
                    } else {
                        await coordinator.connect()
                    }
                }
            }
            .disabled(pending != nil)
        }
    }

    private func connectionStatusText(isConnected: Bool, pending: ConnectionOperation?) -> String {
        switch pending {
        case .connecting: "接続中…"
        case .disconnecting: "切断中…"
        case nil: isConnected ? "接続済み" : "未接続"
        }
    }

    @ViewBuilder
    private var deviceFooter: some View {
        if pairedDevices.isEmpty {
            Label {
                Text("ペアリング済みの機器を読み取れません。システム設定 > プライバシーとセキュリティ > Bluetooth で \(BundleInfo.productName) を許可してから、この画面を開き直してください。")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } else if !hasAudioPairedDevice {
            Text("ペアリング済みの機器にオーディオ機器 (ヘッドフォン・スピーカーなど) がありません。対象にしたい機器をペアリングしてから、この画面を開き直してください。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if settingsStore.settings.registeredDevice == nil {
            Text("切り替えのきっかけにする Bluetooth 機器を 1 台選びます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 出力

    private var outputFallbackSection: some View {
        let usesList = settingsStore.settings.outputFallbackMode == .priorityList
        return Section {
            LabeledContent("切断時の出力先") {
                FallbackModePicker(label: "切断時の出力先", mode: $settingsStore.settings.outputFallbackMode)
            }
            if usesList {
                DevicePriorityList(
                    list: $settingsStore.settings.outputFallback,
                    devices: coordinator.devices,
                    direction: .output,
                    excludedUID: coordinator.registeredEndpoints.output
                )
            }
        } header: {
            Text("出力")
        } footer: {
            Text(usesList
                ? "登録機器が切断されたら、そのとき使えるデバイスのうち一番上のものへ切り替えます。どれも使えないときは切り替えません。"
                : "登録機器が切断されたとき、出力は macOS が選んだものをそのまま使います。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 入力

    private var inputSection: some View {
        let switchesInput = settingsStore.settings.switchesInput
        let usesList = settingsStore.settings.inputFallbackMode == .priorityList
        return Section {
            Toggle(isOn: $settingsStore.settings.switchesInput) {
                Text("入力も切り替える")
                Text("登録機器のマイクが使えるようになったら、既定の入力をその機器にします")
            }
            LabeledContent {
                FallbackModePicker(label: "切断時の入力先", mode: $settingsStore.settings.inputFallbackMode)
            } label: {
                Text("切断時の入力先").opacity(switchesInput ? 1 : Self.disabledOpacity)
            }
            .disabled(!switchesInput)
            if usesList {
                DevicePriorityList(
                    list: $settingsStore.settings.inputFallback,
                    devices: coordinator.devices,
                    direction: .input,
                    excludedUID: coordinator.registeredEndpoints.input
                )
                .disabled(!switchesInput)
                .opacity(switchesInput ? 1 : Self.disabledOpacity)
            }
        } header: {
            Text("入力")
        } footer: {
            Text(usesList
                ? "登録機器が切断されたら、そのとき使えるデバイスのうち一番上のものへ入力を切り替えます。"
                : "登録機器が切断されたとき、入力は macOS が選んだものをそのまま使います。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .opacity(switchesInput ? 1 : Self.disabledOpacity)
        }
    }

    // MARK: - 一般

    private var generalSection: some View {
        Section("一般") {
            LabeledContent("メニューバーアイコン") {
                Picker("メニューバーアイコン", selection: $settingsStore.settings.iconVisibility) {
                    Text("常に表示").tag(IconVisibility.always)
                    Text("接続時のみ表示").tag(IconVisibility.whileConnected)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
            }
            Toggle("ログイン時に起動", isOn: Binding(
                get: { loginItemStatus == .enabled },
                set: { newValue in
                    LoginItem.setEnabled(newValue)
                    loginItemStatus = LoginItem.status
                }
            ))
            if loginItemStatus == .requiresApproval {
                LabeledContent {
                    Button("ログイン項目を開く…") { LoginItem.openSystemSettings() }
                } label: {
                    Label {
                        Text("システム設定での許可を待っています。ログイン項目の「バックグラウンドでの実行を許可」で \(BundleInfo.productName) をオンにしてください。")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

// MARK: - 切断時の出力先/入力先 (自動 / 優先度リスト)

private struct FallbackModePicker: View {
    let label: String
    @Binding var mode: FallbackMode

    var body: some View {
        Picker(label, selection: $mode) {
            Text("自動 (macOS に任せる)").tag(FallbackMode.automatic)
            Text("優先度リスト").tag(FallbackMode.priorityList)
        }
        .pickerStyle(.radioGroup)
        .horizontalRadioGroupLayout()
        .labelsHidden()
    }
}
