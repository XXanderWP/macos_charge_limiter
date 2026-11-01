import Foundation
import IOKit

/// One reading of the AppleSmartBattery registry entry plus the charge control SMC keys.
struct PowerSnapshot {
    var date = Date()
    var percent = 0
    var plugged = false
    var isCharging = false
    var fullyCharged = false
    var batteryVoltage = 0.0   // V
    var batteryCurrent = 0.0   // A, positive while charging
    var temperature = 0.0      // °C
    var adapterWatts: Int?
    var adapterVoltage: Double?
    var inputVoltage: Double?
    var inputCurrent: Double?
    var inputPower: Double?    // W drawn from the adapter
    var cycleCount = 0
    var health = 0.0           // % of design capacity
    var minutesToFull: Int?
    var minutesToEmpty: Int?
    var chargingInhibited = false  // CHTE != 0
    var forcedDischarge = false    // CHIE != 0

    var batteryPower: Double { batteryVoltage * batteryCurrent }
}

enum BatteryReader {
    static func read() -> PowerSnapshot? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return nil }

        func num(_ d: [String: Any]?, _ key: String) -> Int? { (d?[key] as? NSNumber)?.intValue }
        func bool(_ key: String) -> Bool { (dict[key] as? NSNumber)?.boolValue ?? false }
        func minutes(_ key: String) -> Int? {
            guard let m = num(dict, key), m > 0, m < 65535 else { return nil }
            return m
        }

        var s = PowerSnapshot()
        s.percent = num(dict, "CurrentCapacity") ?? 0
        s.plugged = bool("ExternalConnected")
        s.isCharging = bool("IsCharging")
        s.fullyCharged = bool("FullyCharged")
        s.batteryVoltage = Double(num(dict, "Voltage") ?? 0) / 1000
        // Stored as a 64-bit value, negative while discharging
        s.batteryCurrent = Double((dict["Amperage"] as? NSNumber)?.int64Value ?? 0) / 1000
        s.temperature = Double(num(dict, "Temperature") ?? 0) / 100
        s.cycleCount = num(dict, "CycleCount") ?? 0
        if let raw = num(dict, "AppleRawMaxCapacity"), let design = num(dict, "DesignCapacity"), design > 0 {
            s.health = Double(raw) / Double(design) * 100
        }
        s.minutesToFull = s.isCharging ? minutes("AvgTimeToFull") : nil
        s.minutesToEmpty = s.plugged ? nil : minutes("AvgTimeToEmpty")

        if s.plugged {
            let adapter = dict["AdapterDetails"] as? [String: Any]
            s.adapterWatts = num(adapter, "Watts")
            s.adapterVoltage = num(adapter, "AdapterVoltage").map { Double($0) / 1000 }
            let telemetry = dict["PowerTelemetryData"] as? [String: Any]
            s.inputVoltage = num(telemetry, "SystemVoltageIn").map { Double($0) / 1000 }
            s.inputCurrent = num(telemetry, "SystemCurrentIn").map { Double($0) / 1000 }
            s.inputPower = num(telemetry, "SystemPowerIn").map { Double($0) / 1000 }
        }

        s.chargingInhibited = (SMC.read("CHTE") ?? []).contains { $0 != 0 }
        s.forcedDischarge = (SMC.read("CHIE") ?? []).contains { $0 != 0 }
        return s
    }
}
