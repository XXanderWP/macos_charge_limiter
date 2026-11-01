import Foundation

/// Settings shared with the daemon and the CLI: plain files in ~/.charge-limit.
/// The daemon watches this folder, so writing a file applies the change.
struct LimiterConfig: Equatable {
    var enabled = false
    var limit = 80
    var discharge = false
    var language: String?   // en | ru | uk, nil = system

    static let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".charge-limit")
    static let limits = Array(stride(from: 50, through: 95, by: 5))
    static var daemonInstalled: Bool { FileManager.default.fileExists(atPath: "/usr/local/bin/charge-limit-daemon") }

    private static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }
    private static func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: url(name).path) }
    private static func text(_ name: String) -> String? {
        (try? String(contentsOf: url(name), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func load() -> LimiterConfig {
        var c = LimiterConfig()
        c.enabled = exists("on")
        c.discharge = exists("discharge")
        if let v = text("max").flatMap(Int.init), (50...95).contains(v) { c.limit = v }
        if let l = text("lang"), !l.isEmpty { c.language = l }
        return c
    }

    static func setFlag(_ name: String, _ on: Bool) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if on {
            FileManager.default.createFile(atPath: url(name).path, contents: nil)
        } else {
            try? FileManager.default.removeItem(at: url(name))
        }
    }

    static func setLimit(_ value: Int) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "\(value)\n".write(to: url("max"), atomically: true, encoding: .utf8)
    }

    static func setLanguage(_ code: String?) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let code {
            try? "\(code)\n".write(to: url("lang"), atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(at: url("lang"))
        }
    }
}
