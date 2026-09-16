import Foundation

/// Observes one Herdr server and reports session activity. Herdr replays a
/// backlog of recent events on every new subscription, so a subscription only
/// counts as live once its ack is followed by a quiet flush period, and the
/// snapshot taken after that is the baseline nothing celebrates from.
final class HerdrConnection {
    static let flushDelay: TimeInterval = 0.3
    static let reconcileDelay: TimeInterval = 1
    static let initialRetryDelay: TimeInterval = 1
    static let maxRetryDelay: TimeInterval = 30

    var onEvent: ((ActivityEvent) -> Void)?

    private let transport: HerdrTransport
    private let scheduler: DelayScheduler
    private let socketPath: () -> String

    private var currentPath: String?
    private var lifecycle: HerdrSubscriptionHandle?
    private var statusSubscriptions: [String: HerdrSubscriptionHandle] = [:]
    private var known: [String: SessionRecord] = [:]
    private var live = false
    private var running = false
    private var retryDelay = HerdrConnection.initialRetryDelay
    private var pendingWork: [ScheduledWork] = []
    private var reconcileScheduled = false
    private var snapshotInFlight = false
    private var nextRequestID = 0
    private var generation = 0

    init(transport: HerdrTransport, scheduler: DelayScheduler, socketPath: @escaping () -> String) {
        self.transport = transport
        self.scheduler = scheduler
        self.socketPath = socketPath
    }

    func start() {
        guard !running else { return }
        running = true
        retryDelay = Self.initialRetryDelay
        connect()
    }

    func stop() {
        running = false
        drop()
    }

    func refresh() {
        guard running else { return start() }
        let path = socketPath()
        if path != currentPath {
            drop()
            connect()
        } else if lifecycle == nil {
            connect()
        }
    }

    /// Asks Herdr to focus one pane, switching its workspace and tab. Herdr
    /// validates the pane itself, so a closed pane answers `pane_not_found`
    /// rather than focusing anything else.
    func focusPane(_ paneID: String, completion: @escaping (Bool) -> Void) {
        guard live, let path = currentPath else { return completion(false) }
        transport.request(HerdrRequest.focusPane(paneID: paneID).line(id: requestID()), socketPath: path) { result in
            let response = try? JSONDecoder().decode(HerdrResponse<HerdrPaneInfoResult>.self, from: try result.get())
            completion(response?.error == nil && response?.result?.pane.paneID == paneID)
        }
    }

    private func connect() {
        guard running, lifecycle == nil else { return }
        let path = socketPath()
        currentPath = path
        lifecycle = openArmedSubscription(
            [.paneClosed, .paneExited, .paneMoved, .paneAgentDetected],
            at: path,
            onArmed: { [weak self] in self?.bootstrap() },
            onRejected: { [weak self] in self?.fail() },
            onClose: { [weak self] in self?.fail() }
        )
    }

    /// Herdr replays recent events right after acknowledging a subscription,
    /// so events only count once the ack has been followed by a quiet spell.
    private func openArmedSubscription(
        _ subscriptions: [HerdrSubscription],
        at path: String,
        onArmed: @escaping () -> Void,
        onRejected: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) -> HerdrSubscriptionHandle {
        var armed = false
        let generation = generation
        return transport.subscribe(
            HerdrRequest.subscribe(subscriptions).line(id: requestID()),
            socketPath: path,
            onLine: { [weak self] line in
                guard let self, generation == self.generation else { return }
                if let event = HerdrEvent(line: line) {
                    if armed { handle(event) }
                } else if isAcknowledgement(line) {
                    schedule(after: Self.flushDelay) {
                        armed = true
                        onArmed()
                    }
                } else {
                    onRejected()
                }
            },
            onClose: { [weak self] _ in
                guard let self, generation == self.generation else { return }
                onClose()
            }
        )
    }

    private func bootstrap() {
        guard let path = currentPath, running else { return }
        let generation = generation
        transport.request(HerdrRequest.snapshot.line(id: requestID()), socketPath: path) { [weak self] result in
            guard let self, running, generation == self.generation else { return }
            guard let snapshot = Self.snapshot(from: result, during: "bootstrap") else { return fail() }
            let records = snapshot.sessions
            known = Dictionary(records.map { ($0.identity.paneID, $0) }, uniquingKeysWith: { _, last in last })
            live = true
            retryDelay = Self.initialRetryDelay
            onEvent?(.connected(records))
            for paneID in known.keys { ensureStatusSubscription(for: paneID) }
        }
    }

    private func handle(_ event: HerdrEvent) {
        guard live else { return }
        switch event {
        case .agentStatusChanged(let paneID, let agent, let status):
            guard let record = known[paneID] else {
                ensureStatusSubscription(for: paneID)
                scheduleReconcile()
                return
            }
            if let agent, agent != record.identity.agent {
                return scheduleReconcile()
            }
            known[paneID]?.status = status.sessionStatus
            onEvent?(.statusChanged(paneID: paneID, status: status.sessionStatus))

        case .agentDetected(let paneID, _, let released):
            if known[paneID] == nil {
                guard !released else { return }
                ensureStatusSubscription(for: paneID)
            } else if !released {
                return
            }
            scheduleReconcile()

        case .paneRemoved(let paneID):
            forget(paneID)

        case .paneMoved(let previousPaneID, _):
            forget(previousPaneID)
            scheduleReconcile()

        case .other:
            break
        }
    }

    private func forget(_ paneID: String) {
        statusSubscriptions.removeValue(forKey: paneID)?.cancel()
        guard known.removeValue(forKey: paneID) != nil else { return }
        onEvent?(.sessionRemoved(paneID: paneID))
    }

    private func ensureStatusSubscription(for paneID: String) {
        guard let path = currentPath, statusSubscriptions[paneID] == nil else { return }
        statusSubscriptions[paneID] = openArmedSubscription(
            [.agentStatus(paneID: paneID)],
            at: path,
            onArmed: { [weak self] in self?.scheduleReconcile() },
            onRejected: { [weak self] in self?.statusSubscriptions.removeValue(forKey: paneID)?.cancel() },
            onClose: { [weak self] in
                guard let self else { return }
                statusSubscriptions.removeValue(forKey: paneID)
                if live, known[paneID] != nil { scheduleReconcile() }
            }
        )
    }

    private func scheduleReconcile() {
        guard live, !reconcileScheduled else { return }
        reconcileScheduled = true
        schedule(after: Self.reconcileDelay) { [weak self] in
            self?.reconcileScheduled = false
            self?.reconcile()
        }
    }

    private func reconcile() {
        guard let path = currentPath, live, !snapshotInFlight else {
            if live { scheduleReconcile() }
            return
        }
        snapshotInFlight = true
        let generation = generation
        transport.request(HerdrRequest.snapshot.line(id: requestID()), socketPath: path) { [weak self] result in
            guard let self, generation == self.generation else { return }
            snapshotInFlight = false
            guard live else { return }
            guard let snapshot = Self.snapshot(from: result, during: "reconcile") else { return fail() }
            apply(snapshot.sessions)
        }
    }

    private func apply(_ records: [SessionRecord]) {
        let seen = Set(records.map(\.identity.paneID))
        for paneID in known.keys where !seen.contains(paneID) {
            forget(paneID)
        }
        for record in records {
            let paneID = record.identity.paneID
            if let existing = known[paneID] {
                if existing.identity != record.identity {
                    known[paneID] = record
                    onEvent?(.sessionAppeared(record))
                } else if existing.status != record.status {
                    known[paneID]?.status = record.status
                    onEvent?(.statusChanged(paneID: paneID, status: record.status))
                }
            } else {
                known[paneID] = record
                onEvent?(.sessionAppeared(record))
            }
            ensureStatusSubscription(for: paneID)
        }
    }

    private func fail() {
        guard running else { return }
        drop()
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, Self.maxRetryDelay)
        schedule(after: delay) { [weak self] in self?.connect() }
    }

    private func drop() {
        let wasLive = live
        tearDown()
        if wasLive { onEvent?(.disconnected) }
    }

    private func tearDown() {
        generation += 1
        lifecycle?.cancel()
        lifecycle = nil
        statusSubscriptions.values.forEach { $0.cancel() }
        statusSubscriptions = [:]
        known = [:]
        live = false
        reconcileScheduled = false
        snapshotInFlight = false
        pendingWork.forEach { $0.cancel() }
        pendingWork = []
    }

    private func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        var handle: ScheduledWork?
        handle = scheduler.schedule(after: delay) { [weak self] in
            self?.pendingWork.removeAll { $0 === handle }
            work()
        }
        if let handle { pendingWork.append(handle) }
    }

    private func isAcknowledgement(_ line: Data) -> Bool {
        guard let response = try? JSONDecoder().decode(HerdrResponse<HerdrAcknowledgement>.self, from: line) else {
            return false
        }
        return response.error == nil && response.result?.type == "subscription_started"
    }

    private func requestID() -> String {
        nextRequestID += 1
        return "claudey-\(nextRequestID)"
    }

    private static func snapshot(from result: Result<Data, Error>, during phase: String) -> HerdrSnapshot? {
        do {
            return try decodeSnapshot(result)
        } catch {
            NSLog("Claudey could not read Herdr's %@ snapshot: %@", phase, String(describing: error))
            return nil
        }
    }

    private static func decodeSnapshot(_ result: Result<Data, Error>) throws -> HerdrSnapshot {
        let response = try JSONDecoder().decode(HerdrResponse<HerdrSnapshotResult>.self, from: try result.get())
        if let error = response.error { throw error }
        guard let snapshot = response.result?.snapshot else { throw HerdrTransportError.closedWithoutResponse }
        return snapshot
    }
}
