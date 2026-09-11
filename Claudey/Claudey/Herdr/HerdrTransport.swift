import Foundation
import Network

protocol HerdrSubscriptionHandle: AnyObject {
    func cancel()
}

/// Herdr answers exactly one request per connection and then hangs up, so a
/// request and a subscription are separate connections rather than a shared
/// channel. Callbacks are delivered on the main actor.
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
        var answered = false
        var stream: HerdrLineStream?
        stream = HerdrLineStream(
            socketPath: socketPath,
            onLine: { data in
                guard !answered else { return }
                answered = true
                completion(.success(data))
                stream?.cancel()
            },
            onClose: { error in
                guard !answered else { return }
                answered = true
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

/// A newline-delimited JSON connection to Herdr's Unix socket. All state is
/// touched only on the main queue, which is also where Network delivers.
nonisolated final class HerdrLineStream: HerdrSubscriptionHandle, @unchecked Sendable {
    private let connection: NWConnection
    private let onLine: @MainActor (Data) -> Void
    private let onClose: @MainActor (Error?) -> Void
    private var buffer = Data()
    private var closed = false

    init(
        socketPath: String,
        onLine: @escaping @MainActor (Data) -> Void,
        onClose: @escaping @MainActor (Error?) -> Void
    ) {
        connection = NWConnection(to: .unix(path: socketPath), using: .tcp)
        self.onLine = onLine
        self.onClose = onClose
    }

    func start(sending line: Data) {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                connection.send(content: line, completion: .contentProcessed { [weak self] error in
                    if let error { self?.finish(error) }
                })
                receive()
            case .failed(let error):
                finish(error)
            case .waiting(let error):
                finish(HerdrTransportError.unreachable(error.localizedDescription))
            case .cancelled:
                finish(nil)
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    func cancel() {
        finish(nil)
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self, !closed else { return }
            if let data { consume(data) }
            if let error {
                finish(error)
            } else if isComplete {
                finish(nil)
            } else {
                receive()
            }
        }
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            guard !line.isEmpty else { continue }
            let onLine = onLine
            MainActor.assumeIsolated { onLine(line) }
        }
    }

    private func finish(_ error: Error?) {
        guard !closed else { return }
        closed = true
        connection.stateUpdateHandler = nil
        connection.cancel()
        let onClose = onClose
        MainActor.assumeIsolated { onClose(error) }
    }
}
