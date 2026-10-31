import Foundation
import Network

final class RemotePairingPortResolver {
    private let queue = DispatchQueue(label: "com.stik.StikJIT.remote-pairing-discovery")
    private let completion = DispatchSemaphore(value: 0)
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var selectedService: NWEndpoint?
    private var selectedLoopback = false
    private var resolvedPort: UInt16?
    private var finished = false

    static func resolve(fallback: UInt16, timeout: TimeInterval) -> UInt16 {
        let worker = RemotePairingPortResolver()
        worker.queue.async { worker.start() }
        _ = worker.completion.wait(timeout: .now() + max(timeout, 0.1))
        return worker.queue.sync {
            worker.finish()
            return worker.resolvedPort ?? fallback
        }
    }

    private func start() {
        guard !finished else { return }
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_remotepairing._tcp", domain: "local."), using: parameters)
        self.browser = browser
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self, !self.finished else { return }
            let candidates = results.compactMap { result -> (endpoint: NWEndpoint, isLoopback: Bool)? in
                guard case .service = result.endpoint else { return nil }
                return (result.endpoint, result.interfaces.contains { $0.name.hasPrefix("lo") })
            }
            guard let selected = candidates.first(where: { $0.isLoopback }) ?? candidates.first,
                  self.selectedService == nil || (!self.selectedLoopback && selected.isLoopback) else { return }
            self.selectedService = selected.endpoint
            self.selectedLoopback = selected.isLoopback
            self.connection?.cancel()
            let connection = NWConnection(to: selected.endpoint, using: parameters)
            self.connection = connection
            connection.pathUpdateHandler = { [weak self, weak connection] path in
                guard let self, let connection, self.connection === connection, !self.finished else { return }
                if path.status == .satisfied { self.recordPort(from: connection) }
            }
            connection.stateUpdateHandler = { [weak self, weak connection] state in
                guard let self, let connection, self.connection === connection, !self.finished else { return }
                switch state {
                case .ready, .waiting:
                    self.recordPort(from: connection)
                case .failed:
                    self.finish()
                default:
                    break
                }
            }
            connection.start(queue: self.queue)
        }
        browser.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.finish() }
        }
        browser.start(queue: queue)
    }

    private func recordPort(from connection: NWConnection) {
        guard case .hostPort(_, let port) = connection.currentPath?.remoteEndpoint,
              port.rawValue != 0 else { return }
        resolvedPort = port.rawValue
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        browser?.cancel()
        connection?.cancel()
        completion.signal()
    }
}
