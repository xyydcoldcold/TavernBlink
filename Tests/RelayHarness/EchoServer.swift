import Darwin
import Foundation
import Network

final class EchoServer {
    private let acceptQueue = DispatchQueue(
        label: "dev.tavernblink.echo-server.accept"
    )
    private let connectionQueue = DispatchQueue(
        label: "dev.tavernblink.echo-server.connections",
        attributes: .concurrent
    )
    private let lock = NSLock()
    private let responseDelay: TimeInterval
    private var listenerDescriptor: Int32 = -1
    private var connectionDescriptors: Set<Int32> = []
    private var stopped = false

    init(responseDelay: TimeInterval = 0) {
        self.responseDelay = responseDelay
    }

    func start() throws -> NWEndpoint.Port {
        let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard descriptor >= 0 else {
            throw HarnessError.systemCall("socket", errno)
        }

        var reuseAddress: Int32 = 1
        guard setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &reuseAddress,
            socklen_t(MemoryLayout.size(ofValue: reuseAddress))
        ) == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw HarnessError.systemCall("setsockopt", code)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(
                    descriptor,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard bindResult == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw HarnessError.systemCall("bind", code)
        }
        guard Darwin.listen(descriptor, SOMAXCONN) == 0 else {
            let code = errno
            Darwin.close(descriptor)
            throw HarnessError.systemCall("listen", code)
        }

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &boundAddressLength)
            }
        }
        guard nameResult == 0,
              let port = NWEndpoint.Port(
                rawValue: UInt16(bigEndian: boundAddress.sin_port)
              )
        else {
            let code = errno
            Darwin.close(descriptor)
            throw HarnessError.systemCall("getsockname", code)
        }

        lock.lock()
        listenerDescriptor = descriptor
        stopped = false
        lock.unlock()
        acceptQueue.async { [weak self] in
            self?.acceptConnections(from: descriptor)
        }
        return port
    }

    func stop() {
        let listener: Int32
        let connections: [Int32]
        lock.lock()
        guard !stopped else {
            lock.unlock()
            return
        }
        stopped = true
        listener = listenerDescriptor
        listenerDescriptor = -1
        connections = Array(connectionDescriptors)
        connectionDescriptors.removeAll()
        lock.unlock()

        if listener >= 0 {
            Darwin.shutdown(listener, SHUT_RDWR)
            Darwin.close(listener)
        }
        for descriptor in connections {
            Darwin.shutdown(descriptor, SHUT_RDWR)
            Darwin.close(descriptor)
        }
    }

    private func acceptConnections(from listener: Int32) {
        while isRunning {
            let descriptor = Darwin.accept(listener, nil, nil)
            guard descriptor >= 0 else {
                if errno == EINTR {
                    continue
                }
                return
            }

            var noSignal: Int32 = 1
            _ = setsockopt(
                descriptor,
                SOL_SOCKET,
                SO_NOSIGPIPE,
                &noSignal,
                socklen_t(MemoryLayout.size(ofValue: noSignal))
            )
            lock.lock()
            if stopped {
                lock.unlock()
                Darwin.close(descriptor)
                return
            }
            connectionDescriptors.insert(descriptor)
            lock.unlock()

            connectionQueue.async { [weak self] in
                self?.echo(on: descriptor)
            }
        }
    }

    private func echo(on descriptor: Int32) {
        var buffer = [UInt8](repeating: 0, count: 65_536)

        while isRunning {
            let byteCount = Darwin.read(descriptor, &buffer, buffer.count)
            if byteCount == 0 {
                Darwin.shutdown(descriptor, SHUT_WR)
                break
            }
            if byteCount < 0 {
                if errno == EINTR {
                    continue
                }
                break
            }
            if responseDelay > 0 {
                Thread.sleep(forTimeInterval: responseDelay)
            }

            var offset = 0
            while offset < byteCount {
                let written = buffer.withUnsafeBytes { bytes in
                    Darwin.write(
                        descriptor,
                        bytes.baseAddress!.advanced(by: offset),
                        byteCount - offset
                    )
                }
                if written > 0 {
                    offset += written
                } else if written < 0, errno == EINTR {
                    continue
                } else {
                    offset = byteCount
                    break
                }
            }
        }

        lock.lock()
        let shouldClose = connectionDescriptors.remove(descriptor) != nil
        lock.unlock()
        if shouldClose {
            Darwin.close(descriptor)
        }
    }

    private var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !stopped
    }
}

private enum HarnessError: LocalizedError {
    case systemCall(String, Int32)

    var errorDescription: String? {
        switch self {
        case let .systemCall(name, code):
            return "\(name) failed: \(String(cString: strerror(code)))"
        }
    }
}
