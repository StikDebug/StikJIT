import Foundation
#if !os(tvOS)
@_implementationOnly import StikJITIOKit
#endif

enum TXMPresence {
    case present
    case absent
    case unknown

    init(isPresent: Bool?) {
        guard let isPresent else {
            self = .unknown
            return
        }
        self = isPresent ? .present : .absent
    }

    var isPresent: Bool? {
        switch self {
        case .present: return true
        case .absent: return false
        case .unknown: return nil
        }
    }
}

extension ProcessInfo {
    var txmPresence: TXMPresence {
#if os(tvOS)
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return .unknown }
        let machineSize = MemoryLayout.size(ofValue: systemInfo.machine)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: machineSize) {
                String(cString: $0)
            }
        }
        guard identifier.hasPrefix("AppleTV"),
              let comma = identifier.firstIndex(of: ","),
              let major = Int(identifier[identifier.index(identifier.startIndex, offsetBy: 7)..<comma]),
              let minor = Int(identifier[identifier.index(after: comma)...]) else { return .unknown }
        let version = operatingSystemVersion
        return version.majorVersion >= 26 && (major > 14 || (major == 14 && minor >= 1)) ? .present : .absent
#else
        let memoryMap = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/chosen/memory-map")
        guard memoryMap != 0 else { return .unknown }

        let keysCF = IORegistryEntryCreateCFProperty(
            memoryMap,
            kIORegistryEntryPropertyKeysKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue()
        IOObjectRelease(memoryMap)
        guard let keys = keysCF as? [String] else { return .unknown }

        return keys.contains("TXM") ? .present : .absent
#endif
    }
}
