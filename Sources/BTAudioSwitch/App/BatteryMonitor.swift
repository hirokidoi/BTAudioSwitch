import Observation

struct BatteryReading: Equatable {
    let address: String
    let level: Int

    static func displayed(_ reading: BatteryReading?, registeredAddress: String?) -> Int? {
        guard let reading, reading.address == registeredAddress else { return nil }
        return reading.level
    }

    static func updated(
        _ reading: BatteryReading?,
        fetched: Int?,
        requestedAddress: String,
        registeredAddress: String?
    ) -> BatteryReading? {
        guard let fetched, registeredAddress == requestedAddress else { return reading }
        return BatteryReading(address: requestedAddress, level: fetched)
    }
}

@MainActor
@Observable
final class BatteryMonitor {
    private let reader: any BatteryLevelReader
    private let settingsStore: SettingsStore
    private var reading: BatteryReading?
    private var inFlightFetch: (address: String, task: Task<Void, Never>)?

    init(reader: any BatteryLevelReader, settingsStore: SettingsStore) {
        self.reader = reader
        self.settingsStore = settingsStore
    }

    var level: Int? {
        BatteryReading.displayed(reading, registeredAddress: registeredAddress)
    }

    func refresh() async {
        guard let address = registeredAddress else { return }
        if let inFlightFetch, inFlightFetch.address == address {
            await inFlightFetch.task.value
            return
        }
        let fetch = Task {
            let fetched = await self.reader.batteryLevel(address: address)
            self.reading = BatteryReading.updated(self.reading, fetched: fetched, requestedAddress: address, registeredAddress: self.registeredAddress)
        }
        inFlightFetch = (address, fetch)
        await fetch.value
        if inFlightFetch?.task == fetch {
            inFlightFetch = nil
        }
    }

    private var registeredAddress: String? {
        settingsStore.settings.registeredDevice?.address
    }
}
