import Foundation

protocol HerdrSubscriptionHandle: AnyObject {
    func cancel()
}

/// Herdr answers exactly one request per connection and then hangs up, so a
/// request and a subscription are separate connections rather than a shared
/// channel. Callbacks are delivered on the main actor; cancelling a
/// subscription does not report a close.
protocol HerdrTransport: AnyObject {
    func request(
        _ line: Data,
        socketPath: String,
        completion: @escaping @MainActor (Result<Data, Error>) -> Void
    )

    func subscribe(
        _ line: Data,
        socketPath: String,
        onLine: @escaping @MainActor (Data) -> Void,
        onClose: @escaping @MainActor (Error?) -> Void
    ) -> HerdrSubscriptionHandle
}

enum HerdrTransportError: Error, Equatable {
    case closedWithoutResponse
    case unreachable(String)
}

final class HerdrSocketTransport: HerdrTransport {
    func request(
        _ line: Data,
        socketPath: String,
        completion: @escaping @MainActor (Result<Data, Error>) -> Void
    ) {
        var stream: HerdrLineStream?
        stream = HerdrLineStream(
            socketPath: socketPath,
            onLine: { data in
                guard let answering = stream else { return }
                stream = nil
                answering.cancel()
                completion(.success(data))
            },
            onClose: { error in
                guard stream != nil else { return }
                stream = nil
                completion(.failure(error ?? HerdrTransportError.closedWithoutResponse))
            }
        )
        stream?.start(sending: line)
    }

    func subscribe(
        _ line: Data,
        socketPath: String,
        onLine: @escaping @MainActor (Data) -> Void,
        onClose: @escaping @MainActor (Error?) -> Void
    ) -> HerdrSubscriptionHandle {
        let stream = HerdrLineStream(socketPath: socketPath, onLine: onLine, onClose: onClose)
        stream.start(sending: line)
        return stream
    }
}

/// A newline-delimited JSON connection to Herdr's Unix socket over a plain
/// BSD socket. Network.framework was used first, but on the owner's Mac its
/// flows to this socket intermittently fail with ENETDOWN while every BSD
/// socket client succeeds. All state is touched only on the main queue.
nonisolated final class HerdrLineStream: HerdrSubscriptionHandle, @unchecked Sendable {
    private let socketPath: String
    private let onLine: @MainActor (Data) -> Void
    private let onClose: @MainActor (Error?) -> Void
    private var descriptor: Int32 = -1
    private var reader: DispatchSourceRead?
    private var buffer = Data()
    private var closed = false

    init(
        socketPath: String,
        onLine: @escaping @MainActor (Data) -> Void,
        onClose: @escaping @MainActor (Error?) -> Void
    ) {
        self.socketPath = socketPath
        self.onLine = onLine
        self.onClose = onClose
    }

    func start(sending line: Data) {
        do {
            descriptor = try Self.connect(to: socketPath)
            try Self.write(line, to: descriptor)
        } catch {
            return finish(error)
        }

        let reader = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: .main)
        reader.setEventHandler { [weak self] in self?.read() }
        let descriptor = descriptor
        reader.setCancelHandler { close(descriptor) }
        reader.resume()
        self.reader = reader
    }

    func cancel() {
        finish(nil, notify: false)
    }

    private func read() {
        var chunk = [UInt8](repeating: 0, count: 1 << 16)
        let count = Darwin.read(descriptor, &chunk, chunk.count)
        if count > 0 {
            consume(Data(chunk[..<count]))
        } else if count == 0 {
            finish(nil)
        } else if errno != EAGAIN, errno != EINTR {
            finish(Self.posixError())
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty, !closed else { continue }
            let onLine = onLine
            MainActor.assumeIsolated { onLine(line) }
        }
    }

    private func finish(_ error: Error?, notify: Bool = true) {
        guard !closed else { return }
        closed = true
        if let reader {
            reader.cancel()
        } else if descriptor >= 0 {
            close(descriptor)
        }
        descriptor = -1
        guard notify else { return }
        let onClose = onClose
        MainActor.assumeIsolated { onClose(error) }
    }

    private static func connect(to path: String) throws -> Int32 {
        var address = sockaddr_un()
        let bytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard bytes.count < capacity else { throw HerdrTransportError.unreachable("socket path too long") }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw posixError() }
        var noSignal: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))

        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else {
            let error = posixError()
            close(descriptor)
            throw error
        }
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        return descriptor
    }

    private static func write(_ line: Data, to descriptor: Int32) throws {
        try line.withUnsafeBytes { raw in
            var sent = 0
            while sent < raw.count {
                let count = Darwin.write(descriptor, raw.baseAddress! + sent, raw.count - sent)
                if count < 0 {
                    if errno == EAGAIN || errno == EINTR { continue }
                    throw posixError()
                }
                sent += count
            }
        }
    }

    private static func posixError() -> Error {
        HerdrTransportError.unreachable(String(cString: strerror(errno)))
    }
}
