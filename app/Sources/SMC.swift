import Foundation
import IOKit

/// Minimal read-only access to the AppleSMC user client (no root needed for reads).
/// Struct layout mirrors SMCKeyData_t from Apple's smc tool.
enum SMC {
    private typealias Bytes32 = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    private struct Version { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0; var release: UInt16 = 0 }
    private struct PLimitData { var version: UInt16 = 0, length: UInt16 = 0; var cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
    // Explicit padding: Swift would otherwise put the next fields into the tail padding, C does not
    private struct KeyInfo { var dataSize: UInt32 = 0, dataType: UInt32 = 0; var dataAttributes: UInt8 = 0; var pad: (UInt8, UInt8, UInt8) = (0, 0, 0) }
    private struct KeyData {
        var key: UInt32 = 0
        var vers = Version()
        var pLimitData = PLimitData()
        var keyInfo = KeyInfo()
        var result: UInt8 = 0, status: UInt8 = 0, data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: Bytes32 = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                              0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    }

    private static let handleEvent: UInt32 = 2
    private static let cmdReadKey: UInt8 = 5
    private static let cmdKeyInfo: UInt8 = 9

    private static var connection: io_connect_t = {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }
        var conn: io_connect_t = 0
        return IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS ? conn : 0
    }()

    private static func call(_ input: inout KeyData) -> KeyData? {
        guard connection != 0 else { return nil }
        var output = KeyData()
        var outSize = MemoryLayout<KeyData>.stride
        let result = IOConnectCallStructMethod(connection, handleEvent, &input, MemoryLayout<KeyData>.stride, &output, &outSize)
        return result == KERN_SUCCESS && output.result == 0 ? output : nil
    }

    /// Raw bytes of an SMC key, e.g. read("CHTE") -> [1, 0, 0, 0].
    static func read(_ key: String) -> [UInt8]? {
        let code = key.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        var info = KeyData()
        info.key = code
        info.data8 = cmdKeyInfo
        guard let keyInfo = call(&info)?.keyInfo, keyInfo.dataSize > 0 else { return nil }

        var request = KeyData()
        request.key = code
        request.keyInfo.dataSize = keyInfo.dataSize
        request.data8 = cmdReadKey
        guard let out = call(&request) else { return nil }
        let all = withUnsafeBytes(of: out.bytes) { Array($0) }
        return Array(all.prefix(Int(keyInfo.dataSize)))
    }
}
