import SwiftUI
import Charts
import AppKit

struct PopoverView: View {
    @ObservedObject var monitor: Monitor

    var body: some View {
        let l = monitor.l10n
        VStack(alignment: .leading, spacing: 12) {
            HeaderView(snapshot: monitor.snapshot, config: monitor.config, l: l)
            if !LimiterConfig.daemonInstalled {
                Label(l.daemonMissing, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            LimitCard(monitor: monitor, l: l)
            if let s = monitor.snapshot {
                MetricsGrid(s: s, l: l)
            }
            ChartCard(history: monitor.history, config: monitor.config, l: l)
            FooterView(monitor: monitor, l: l)
        }
        .padding(14)
        .frame(width: 340)
    }
}

// MARK: - Header

private struct HeaderView: View {
    let snapshot: PowerSnapshot?
    let config: LimiterConfig
    let l: L10n

    private var state: (text: String, icon: String, color: Color) {
        guard let s = snapshot else { return ("—", "questionmark", .secondary) }
        if s.forcedDischarge { return (l.stateDischarging(config.limit), "arrow.down.circle.fill", .orange) }
        if s.plugged && s.chargingInhibited { return (l.stateHolding(config.limit - 5, config.limit), "leaf.fill", .green) }
        if s.plugged && s.isCharging { return (l.stateCharging, "bolt.fill", .blue) }
        if s.plugged && s.fullyCharged { return (l.stateFull, "checkmark.circle.fill", .green) }
        if s.plugged { return (l.stateNotCharging, "powerplug.fill", .secondary) }
        return (l.stateOnBattery, "battery.75percent", .secondary)
    }

    private var timeText: String? {
        guard let s = snapshot else { return nil }
        if let m = s.minutesToFull, !s.chargingInhibited { return l.toFull(Format.duration(m)) }
        if let m = s.minutesToEmpty { return l.remaining(Format.duration(m)) }
        return nil
    }

    var body: some View {
        HStack(spacing: 14) {
            BatteryRing(percent: snapshot?.percent ?? 0,
                        limit: config.enabled ? config.limit : nil,
                        color: state.color)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(snapshot?.percent ?? 0)%")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Label(state.text, systemImage: state.icon)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(state.color)
                if let timeText {
                    Text(timeText).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct BatteryRing: View {
    let percent: Int
    let limit: Int?
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(percent) / 100)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: percent)
            if let limit {
                // Tick mark at the limit
                Capsule()
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: 2.5, height: 11)
                    .offset(y: -32)
                    .rotationEffect(.degrees(Double(limit) / 100 * 360))
            }
            Image(systemName: "battery.100percent")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Limit controls

private struct LimitCard: View {
    @ObservedObject var monitor: Monitor
    let l: L10n
    @State private var slider = 80.0
    @State private var editing = false

    var body: some View {
        let config = monitor.config
        Card {
            HStack {
                Label(l.chargeLimit, systemImage: "leaf")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: Binding(get: { config.enabled }, set: { monitor.setEnabled($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            HStack(spacing: 10) {
                Slider(value: $slider, in: 50...95, step: 5) { isEditing in
                    editing = isEditing
                    if !isEditing { monitor.setLimit(Int(slider)) }
                }
                Text("\(Int(slider))%")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 42, alignment: .trailing)
            }
            .disabled(!config.enabled)
            .opacity(config.enabled ? 1 : 0.45)
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.dischargeToLimit)
                    Text(l.dischargeHint).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { config.discharge }, set: { monitor.setDischarge($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .disabled(!config.enabled)
            .opacity(config.enabled ? 1 : 0.45)
        }
        .onAppear { slider = Double(config.limit) }
        .onChange(of: config.limit) { value in
            if !editing { slider = Double(value) }
        }
    }
}

// MARK: - Live metrics

private struct MetricsGrid: View {
    let s: PowerSnapshot
    let l: L10n

    var body: some View {
        var tiles: [Tile] = []
        if s.plugged, let w = s.adapterWatts {
            tiles.append(Tile(icon: "powerplug.fill", title: l.adapter, value: "\(w) W",
                              detail: s.adapterVoltage.map { Format.num($0, 0) + " V" }))
        }
        if s.plugged, let p = s.inputPower {
            tiles.append(Tile(icon: "bolt.fill", title: l.input, value: Format.num(p, 1) + " W",
                              detail: "\(Format.num(s.inputVoltage ?? 0, 2)) V · \(Format.num(s.inputCurrent ?? 0, 2)) A"))
        }
        tiles.append(Tile(icon: "battery.75percent", title: l.battery, value: Format.signed(s.batteryPower, 1) + " W",
                          detail: "\(Format.num(s.batteryVoltage, 2)) V · \(Format.signed(s.batteryCurrent, 2)) A"))
        tiles.append(Tile(icon: "thermometer.medium", title: l.temperature, value: Format.num(s.temperature, 1) + " °C",
                          detail: nil))
        tiles.append(Tile(icon: "heart.fill", title: l.health, value: Format.num(s.health, 0) + "%",
                          detail: l.cycles(s.cycleCount)))

        // Plain stacks instead of a lazy grid: lazy containers report a wrong height to the popover
        return VStack(spacing: 8) {
            ForEach(Array(stride(from: 0, to: tiles.count, by: 2)), id: \.self) { i in
                HStack(spacing: 8) {
                    tiles[i]
                    if i + 1 < tiles.count {
                        tiles[i + 1]
                    } else {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct Tile: View {
    let icon: String
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text(detail ?? " ")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }
}

// MARK: - Charts

private struct ChartCard: View {
    let history: [Sample]
    let config: LimiterConfig
    let l: L10n

    enum Kind: Hashable { case charge, power }
    @State private var kind = Kind.charge
    @State private var span: TimeInterval = 900

    private var samples: [Sample] {
        let cutoff = Date().addingTimeInterval(-span)
        return history.filter { $0.date >= cutoff }
    }

    var body: some View {
        Card {
            HStack {
                Picker("", selection: $kind) {
                    Text(l.chartCharge).tag(Kind.charge)
                    Text(l.chartPower).tag(Kind.power)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
                Spacer()
                Picker("", selection: $span) {
                    Text("15m").tag(TimeInterval(900))
                    Text("1h").tag(TimeInterval(3600))
                    Text("3h").tag(TimeInterval(10800))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)
            }
            let data = samples
            if data.count < 2 {
                Text(l.collecting)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 130)
            } else if kind == .charge {
                chargeChart(data).frame(height: 130)
            } else {
                powerChart(data).frame(height: 130)
            }
        }
    }

    private func chargeChart(_ data: [Sample]) -> some View {
        let domain = yDomain(data)
        return Chart {
            ForEach(data) { s in
                AreaMark(x: .value("Time", s.date), yStart: .value("%", domain.lowerBound), yEnd: .value("%", s.percent))
                    .foregroundStyle(LinearGradient(colors: [.green.opacity(0.35), .green.opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Time", s.date), y: .value("%", s.percent))
                    .foregroundStyle(.green)
                    .interpolationMethod(.monotone)
            }
            if config.enabled {
                RuleMark(y: .value(l.limitLine, config.limit))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("\(l.limitLine) \(config.limit)%").font(.caption2).foregroundStyle(.secondary)
                    }
            }
        }
        .chartYScale(domain: domain)
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartPlotStyle { $0.clipped() }
    }

    private func yDomain(_ data: [Sample]) -> ClosedRange<Int> {
        var values = data.map(\.percent)
        if config.enabled { values.append(config.limit) }
        let lo = max(0, (values.min() ?? 0) - 5)
        let hi = min(100, (values.max() ?? 100) + 5)
        return lo...max(hi, lo + 10)
    }

    private func powerChart(_ data: [Sample]) -> some View {
        Chart {
            ForEach(data) { s in
                if let p = s.inputPower {
                    LineMark(x: .value("Time", s.date), y: .value("W", p), series: .value("Series", l.input))
                        .foregroundStyle(by: .value("Series", l.input))
                        .interpolationMethod(.monotone)
                }
                LineMark(x: .value("Time", s.date), y: .value("W", s.batteryPower), series: .value("Series", l.battery))
                    .foregroundStyle(by: .value("Series", l.battery))
                    .interpolationMethod(.monotone)
            }
            RuleMark(y: .value("W", 0))
                .foregroundStyle(Color.primary.opacity(0.2))
        }
        .chartForegroundStyleScale([l.input: Color.blue, l.battery: Color.orange])
        .chartLegend(position: .bottom, alignment: .leading)
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartPlotStyle { $0.clipped() }
    }
}

// MARK: - Footer

private struct FooterView: View {
    @ObservedObject var monitor: Monitor
    let l: L10n

    var body: some View {
        HStack {
            Menu {
                Button(l.system) { monitor.setLanguage(nil) }
                Divider()
                Button("English") { monitor.setLanguage("en") }
                Button("Русский") { monitor.setLanguage("ru") }
                Button("Українська") { monitor.setLanguage("uk") }
            } label: {
                Label(l.language, systemImage: "globe")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Spacer()
            Button(l.quit) { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Helpers

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }
}

enum Format {
    static func num(_ v: Double, _ digits: Int) -> String { String(format: "%.\(digits)f", v) }
    static func signed(_ v: Double, _ digits: Int) -> String { (v > 0.004 ? "+" : "") + num(v, digits) }
    static func duration(_ minutes: Int) -> String { String(format: "%d:%02d", minutes / 60, minutes % 60) }
}
