import Foundation

/// UI strings in English, Russian and Ukrainian. The language comes from ~/.charge-limit/lang,
/// otherwise from the first supported entry in the system language list, English as fallback.
struct L10n {
    static let supported = ["en", "ru", "uk"]

    let code: String

    init(override: String?) {
        if let o = override, L10n.supported.contains(o) {
            code = o
        } else {
            code = Locale.preferredLanguages
                .map { String($0.prefix(2)) }
                .first { L10n.supported.contains($0) } ?? "en"
        }
    }

    private func t(_ en: String, _ ru: String, _ uk: String) -> String {
        switch code {
        case "ru": return ru
        case "uk": return uk
        default: return en
        }
    }

    var appName: String { "Charge Limiter" }
    var chargeLimit: String { t("Charge limit", "Лимит зарядки", "Ліміт заряджання") }
    var dischargeToLimit: String { t("Discharge to limit", "Разряжать до лимита", "Розряджати до ліміту") }
    var dischargeHint: String {
        t("Run from battery down to the limit even when plugged in",
          "Работать от батареи до лимита, даже когда адаптер подключён",
          "Працювати від батареї до ліміту, навіть коли адаптер підключено")
    }

    func stateDischarging(_ limit: Int) -> String { t("Discharging to \(limit)%", "Разряжаю до \(limit)%", "Розряджаю до \(limit)%") }
    func stateHolding(_ min: Int, _ max: Int) -> String { t("Holding \(min)–\(max)%", "Держу \(min)–\(max)%", "Тримаю \(min)–\(max)%") }
    var stateCharging: String { t("Charging", "Заряжается", "Заряджається") }
    var stateFull: String { t("Fully charged", "Полностью заряжен", "Повністю заряджено") }
    var stateNotCharging: String { t("Not charging", "Не заряжается", "Не заряджається") }
    var stateOnBattery: String { t("On battery", "От батареи", "Від батареї") }

    var adapter: String { t("Adapter", "Адаптер", "Адаптер") }
    var input: String { t("Input", "Вход", "Вхід") }
    var battery: String { t("Battery", "Батарея", "Батарея") }
    var temperature: String { t("Temperature", "Температура", "Температура") }
    var health: String { t("Health", "Здоровье", "Стан") }
    func cycles(_ n: Int) -> String { t("\(n) cycles", "\(n) циклов", "\(n) циклів") }
    func toFull(_ time: String) -> String { t("\(time) to full", "\(time) до полной", "\(time) до повної") }
    func remaining(_ time: String) -> String { t("\(time) left", "осталось \(time)", "залишилось \(time)") }

    var chartCharge: String { t("Charge", "Заряд", "Заряд") }
    var chartPower: String { t("Power", "Мощность", "Потужність") }
    var collecting: String { t("Collecting data…", "Собираю данные…", "Збираю дані…") }
    var limitLine: String { t("Limit", "Лимит", "Ліміт") }

    var language: String { t("Language", "Язык", "Мова") }
    var system: String { t("System", "Системный", "Системна") }
    var quit: String { t("Quit", "Выйти", "Вийти") }
    var daemonMissing: String {
        t("Daemon is not installed. Run install.sh.",
          "Демон не установлен. Запусти install.sh.",
          "Демон не встановлено. Запусти install.sh.")
    }
}
