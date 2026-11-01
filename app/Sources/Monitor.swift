import Foundation
import Combine

struct Sample: Identifiable {
    let date: Date
    let percent: Int
    let inputPower: Double?
    let batteryPower: Double
    var id: Date { date }
}

/// Polls the battery, keeps a short history for the charts and mirrors the config files.
@MainActor
final class Monitor: ObservableObject {
    @Published private(set) var snapshot: PowerSnapshot?
    @Published private(set) var history: [Sample] = []
    @Published private(set) var config = LimiterConfig.load()
    @Published private(set) var l10n = L10n(override: LimiterConfig.load().language)

    /// Faster refresh while the popover is open.
    var visible = false { didSet { if visible != oldValue { refresh(); schedule() } } }

    static let historySpan: TimeInterval = 3 * 3600
    private let sampleEvery: TimeInterval = 5
    private var timer: Timer?

    init() {
        refresh()
        schedule()
    }

    private func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: visible ? 1 : sampleEvery, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = visible ? 0.1 : 1
    }

    func refresh() {
        let c = LimiterConfig.load()
        if c != config {
            config = c
            l10n = L10n(override: c.language)
        }
        guard let s = BatteryReader.read() else { return }
        snapshot = s
        if history.last.map({ s.date.timeIntervalSince($0.date) >= sampleEvery - 0.5 }) ?? true {
            history.append(Sample(date: s.date, percent: s.percent, inputPower: s.inputPower, batteryPower: s.batteryPower))
            let cutoff = s.date.addingTimeInterval(-Monitor.historySpan)
            if let first = history.firstIndex(where: { $0.date >= cutoff }), first > 0 {
                history.removeFirst(first)
            }
        }
    }

    // MARK: - Actions (write config files, the daemon reacts within a few seconds)

    func setEnabled(_ on: Bool) { LimiterConfig.setFlag("on", on); refresh() }
    func setDischarge(_ on: Bool) { LimiterConfig.setFlag("discharge", on); refresh() }
    func setLimit(_ value: Int) { LimiterConfig.setLimit(value); refresh() }
    func setLanguage(_ code: String?) { LimiterConfig.setLanguage(code); refresh() }
}
