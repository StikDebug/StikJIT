import Foundation

public enum StikJIT {

    public enum Script: Sendable {

        case universal

        case legacy

        case custom(URL)

        case customBase64(String)

        var name: String {
            switch self {
            case .universal: return "universal"
            case .legacy: return "legacy"
            case .custom(let url): return url.lastPathComponent
            case .customBase64: return "custom"
            }
        }
    }

    public struct DeviceSecurityState: Sendable {

        public let isTXMPresent: Bool?

        public init(isTXMPresent: Bool?) {
            self.isTXMPresent = isTXMPresent
        }
    }

    public enum PreparationStage: Sendable {

        case checkingReachability

        case checkingDDI

        case downloadingDDI(fraction: Double, status: String)

        case mountingDDI(fraction: Double)

        case verifyingDDI

        case ready
    }

    public enum JITReadiness: Sendable {

        case unreachable(reason: String)

        case preparationFailed(reason: String)

        case ready(DeviceSecurityState)

        public var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    public struct Configuration: Sendable {

        public var deviceAddress: String

        public var rsdPort: UInt16

        public var automaticallyDiscoverRSDPort: Bool

        public var connectionTimeout: TimeInterval

        public init(deviceAddress: String = "10.7.0.1",
                    rsdPort: UInt16 = 49152,
                    automaticallyDiscoverRSDPort: Bool? = nil,
                    connectionTimeout: TimeInterval = 5) {
            self.deviceAddress = deviceAddress
            self.rsdPort = rsdPort
            self.automaticallyDiscoverRSDPort = automaticallyDiscoverRSDPort ?? (rsdPort == 49152)
            self.connectionTimeout = connectionTimeout
        }

        public static var `default`: Configuration { Configuration() }

        func resolved() -> Configuration {
            guard automaticallyDiscoverRSDPort else { return self }
            var configuration = self
            configuration.rsdPort = RemotePairingPortResolver.resolve(fallback: rsdPort, timeout: connectionTimeout)
            configuration.automaticallyDiscoverRSDPort = false
            return configuration
        }
    }

    @available(*, deprecated, message: "Use enableJIT with ddiPaths to prepare the device before enabling JIT.")
    public static func enableJIT(targetPID: Int32,
                                 pairingFile: URL,
                                 configuration: Configuration = .default,
                                 script: Script = .universal,
                                 forceScript: Bool = false,
                                 progress: @escaping (String) -> Void = { _ in }) throws {
        let txmPresence = ProcessInfo.processInfo.txmPresence
        let session = JITSession(pairingFilePath: pairingFile.path, configuration: configuration.resolved())
        try session.enableJIT(targetPID: targetPID,
                              script: script,
                              forceScript: forceScript,
                              txmPresence: txmPresence,
                              progress: progress)
    }

    public static func enableJIT(targetPID: Int32,
                                 pairingFile: URL,
                                 ddiPaths: DDIPaths,
                                 configuration: Configuration = .default,
                                 script: Script = .universal,
                                 forceScript: Bool = false,
                                 preparationProgress: @escaping (PreparationStage) -> Void = { _ in },
                                 progress: @escaping (String) -> Void = { _ in }) throws {
        let resolvedConfiguration = configuration.resolved()
        let readiness = prepareDevice(pairingFile: pairingFile,
                                      paths: ddiPaths,
                                      configuration: resolvedConfiguration,
                                      progress: preparationProgress)
        let securityState: DeviceSecurityState
        switch readiness {
        case .ready(let readySecurityState):
            securityState = readySecurityState
        case .unreachable(let reason), .preparationFailed(let reason):
            throw StikJITError.deviceNotReady(reason)
        }

        let session = JITSession(pairingFilePath: pairingFile.path, configuration: resolvedConfiguration)
        try session.enableJIT(targetPID: targetPID,
                              script: script,
                              forceScript: forceScript,
                              txmPresence: TXMPresence(isPresent: securityState.isTXMPresent),
                              progress: progress)
    }

    public static var isTXMPresent: Bool? {
        ProcessInfo.processInfo.txmPresence.isPresent
    }

    public static func prepareDevice(pairingFile: URL,
                                     paths: DDIPaths,
                                     configuration: Configuration = .default,
                                     progress: @escaping (PreparationStage) -> Void = { _ in }) -> JITReadiness {
        progress(.checkingReachability)
        let configuration = configuration.resolved()
        if let reason = EndpointProbe.failureReason(address: configuration.deviceAddress,
                                                    port: configuration.rsdPort,
                                                    timeout: configuration.connectionTimeout) {
            return .unreachable(reason: reason)
        }

        do {
            progress(.checkingDDI)
            let session = DDISession(pairingFilePath: pairingFile.path, configuration: configuration)
            if try !session.isMounted() {
                if !paths.allFilesUsable {
                    try SynchronousDDIDownloader.download(to: paths) { fraction, status in
                        progress(.downloadingDDI(fraction: fraction, status: status))
                    }
                }
                try session.mountDDI(paths: paths) { fraction in
                    progress(.mountingDDI(fraction: fraction))
                }
                progress(.verifyingDDI)
                guard try session.isMounted() else {
                    throw StikJITError.ddiNotMounted
                }
            }

            let securityState = DeviceSecurityState(isTXMPresent: isTXMPresent)
            progress(.ready)
            return .ready(securityState)
        } catch {
            return .preparationFailed(reason: error.localizedDescription)
        }
    }

    public static func resetCachedDDI(at paths: DDIPaths) throws {
        try paths.removeCachedFiles()
    }

    public static func isDDIMounted(pairingFile: URL,
                                    configuration: Configuration = .default) throws -> Bool {
        try DDISession(pairingFilePath: pairingFile.path, configuration: configuration.resolved()).isMounted()
    }

    @available(iOS 17.4, tvOS 17.4, *)
    public static func downloadDDIIfNeeded(to paths: DDIPaths,
                                           progress: @escaping (Double, String) -> Void = { _, _ in }) async throws {
        try await DeveloperDiskImageService.shared.downloadIfNeeded(to: paths, progress: progress)
    }

    public static func mountDDI(pairingFile: URL,
                                configuration: Configuration = .default,
                                paths: DDIPaths,
                                progress: @escaping (Double) -> Void = { _ in }) throws {
        let session = DDISession(pairingFilePath: pairingFile.path, configuration: configuration.resolved())
        try session.mountDDI(paths: paths, progress: progress)
    }
}
