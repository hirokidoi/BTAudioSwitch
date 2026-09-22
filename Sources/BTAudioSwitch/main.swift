import AppKit

if CommandLine.arguments.count == 3, CommandLine.arguments[1] == IOBluetoothBatteryReader.argument {
    if let level = IOBluetoothBatteryReader.readInProcess(address: CommandLine.arguments[2]) {
        print(level)
    }
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
