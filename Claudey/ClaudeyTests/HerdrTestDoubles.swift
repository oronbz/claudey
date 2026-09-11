import Foundation
@testable import Claudey

final class FakeHerdrTransport: HerdrTransport {
    final class Subscription: HerdrSubscriptionHandle {
        let id: String
        let socketPath: String
        let types: [[String: String]]
        let onLine: @MainActor (Data) -> Void
        let onClose: @MainActor (Error?) -> Void
        private(set) var isCancelled = false

        init(id: String, socketPath: String, types: [[String: String]],
             onLine: @escaping @MainActor (Data) -> Void, onClose: @escaping @MainActor (Error?) -> Void) {
            self.id = id
            self.socketPath = socketPath
            self.types = types
            self.onLine = onLine
            self.onClose = onClose
        }

        func cancel() { isCancelled = true }

        func acknowledge() { onLine(HerdrFixtures.ack(id: id)) }
        func push(_ line: Data) { onLine(line) }
        func close(_ error: Error? = nil) { onClose(error) }

        var paneID: String? { types.first?["pane_id"] }
        var isLifecycle: Bool { types.contains { $0["type"] == "pane.closed" } }
    }

    struct Request {
        let id: String
        let method: String
        let socketPath: String
        let completion: @MainActor (Result<Data, Error>) -> Void
    }

    private(set) var requests: [Request] = []
    private(set) var subscriptions: [Subscription] = []

    var methodsRequested: [String] {
        requests.map(\.method) + subscriptions.map { _ in "events.subscribe" }
    }

    var lifecycle: Subscription? { subscriptions.last(where: \.isLifecycle) }
    var liveLifecycle: Subscription? { subscriptions.last { $0.isLifecycle && !$0.isCancelled } }

    func statusSubscription(for paneID: String) -> Subscription? {
        subscriptions.last { $0.paneID == paneID && !$0.isCancelled }
    }

    var pendingSnapshot: Request? { requests.last { $0.method == "session.snapshot" } }

    func request(_ line: Data, socketPath: String, completion: @escaping @MainActor (Result<Data, Error>) -> Void) {
        let body = try! JSONSerialization.jsonObject(with: line) as! [String: Any]
        requests.append(Request(id: body["id"] as! String, method: body["method"] as! String, socketPath: socketPath, completion: completion))
    }

    func subscribe(_ line: Data, socketPath: String,
                   onLine: @escaping @MainActor (Data) -> Void,
                   onClose: @escaping @MainActor (Error?) -> Void) -> HerdrSubscriptionHandle {
        let body = try! JSONSerialization.jsonObject(with: line) as! [String: Any]
        let params = body["params"] as! [String: Any]
        let subscription = Subscription(
            id: body["id"] as! String,
            socketPath: socketPath,
            types: params["subscriptions"] as! [[String: String]],
            onLine: onLine,
            onClose: onClose
        )
        subscriptions.append(subscription)
        return subscription
    }

    func answerSnapshot(with agents: [String]) {
        let request = requests.removeLast()
        precondition(request.method == "session.snapshot")
        request.completion(.success(HerdrFixtures.snapshotResponse(id: request.id, agents: agents)))
    }

    func failSnapshot() {
        let request = requests.removeLast()
        precondition(request.method == "session.snapshot")
        request.completion(.failure(HerdrTransportError.unreachable("gone")))
    }
}

final class ManualScheduler: DelayScheduler {
    final class Work: ScheduledWork {
        let due: TimeInterval
        let body: () -> Void
        var isCancelled = false
        init(due: TimeInterval, body: @escaping () -> Void) { self.due = due; self.body = body }
        func cancel() { isCancelled = true }
    }

    private(set) var now: TimeInterval = 0
    private var queue: [Work] = []

    func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) -> ScheduledWork {
        let item = Work(due: now + delay, body: work)
        queue.append(item)
        return item
    }

    func advance(by delta: TimeInterval) {
        let target = now + delta
        while let next = queue.filter({ !$0.isCancelled && $0.due <= target }).min(by: { $0.due < $1.due }) {
            now = max(now, next.due)
            queue.removeAll { $0 === next }
            next.body()
        }
        now = target
    }

    var pendingDelays: [TimeInterval] { queue.filter { !$0.isCancelled }.map { $0.due - now } }
}
