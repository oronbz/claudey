import Foundation
import Testing
@testable import Claudey

/// Drives realistic Herdr traffic through the adapter and watches what
/// Claudey shows. Time is the manual scheduler's clock.
struct HerdrConnectionTests {
    private final class Harness {
        let transport = FakeHerdrTransport()
        let scheduler = ManualScheduler()
        let behavior: CompanionBehavior
        let director: CompanionDirector
        let connection: HerdrConnection
        var socketPath = "/tmp/herdr.sock"
        var events: [ActivityEvent] = []

        init() throws {
            behavior = CompanionBehavior(catalog: try AnimationCatalog.bundled(), startedAt: 0)
            director = CompanionDirector(behavior: behavior)
            var path: () -> String = { "/tmp/herdr.sock" }
            connection = HerdrConnection(transport: transport, scheduler: scheduler) { path() }
            path = { [unowned self] in self.socketPath }
            connection.onEvent = { [unowned self] event in
                events.append(event)
                director.apply(event, at: scheduler.now)
            }
        }

        var animation: CompanionAnimation { behavior.presentation(at: scheduler.now).animation }

        func animation(after delta: TimeInterval) -> CompanionAnimation {
            behavior.presentation(at: scheduler.now + delta).animation
        }

        /// Connects and brings the lifecycle subscription live with the given agents.
        func goLive(agents: [String]) throws {
            connection.start()
            let lifecycle = try #require(transport.liveLifecycle)
            lifecycle.acknowledge()
            scheduler.advance(by: HerdrConnection.flushDelay)
            transport.answerSnapshot(with: agents)
        }

        /// Arms every status subscription that is still waiting for its ack.
        func armStatusSubscriptions() {
            for subscription in transport.subscriptions where !subscription.isCancelled && subscription.paneID != nil {
                subscription.acknowledge()
            }
            scheduler.advance(by: HerdrConnection.flushDelay)
        }

        /// Answers the reconcile snapshot that arming schedules.
        func settle(agents: [String]) {
            scheduler.advance(by: HerdrConnection.reconcileDelay)
            if transport.pendingSnapshot != nil { transport.answerSnapshot(with: agents) }
        }
    }

    private let working = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "working", session: "sess-a", seq: 40)
    private let ready = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "idle", session: "sess-a", seq: 41)
    private let done = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "done", session: "sess-a", seq: 41)
    private let codexWorking = HerdrFixtures.agent(pane: "w1:p2", terminal: "term_b", agent: "codex", status: "working", session: "sess-b", seq: 42)

    @Test func restsUntilTheSnapshotArrivesThenReflectsIt() throws {
        let h = try Harness()
        h.connection.start()

        #expect(h.animation == .idle)
        let lifecycle = try #require(h.transport.liveLifecycle)
        #expect(lifecycle.types.map { $0["type"]! }.sorted() == ["pane.agent_detected", "pane.closed", "pane.exited", "pane.moved"])
        #expect(h.transport.pendingSnapshot == nil)

        lifecycle.acknowledge()
        h.scheduler.advance(by: HerdrConnection.flushDelay)
        #expect(h.transport.pendingSnapshot != nil)

        h.transport.answerSnapshot(with: [working])
        #expect(h.animation == .working)
        #expect(h.transport.statusSubscription(for: "w1:p1") != nil)
    }

    @Test func aQuietInitialSnapshotNeverCelebrates() throws {
        let h = try Harness()
        try h.goLive(agents: [ready, done])

        #expect(h.animation == .idle)
        #expect(h.animation(after: 0.2) == .idle)
    }

    @Test func replayedEventsBeforeTheBaselineAreIgnored() throws {
        let h = try Harness()
        h.connection.start()
        let lifecycle = try #require(h.transport.liveLifecycle)
        lifecycle.acknowledge()
        lifecycle.push(HerdrFixtures.paneClosed(pane: "w1:p1"))
        h.scheduler.advance(by: HerdrConnection.flushDelay)
        h.transport.answerSnapshot(with: [working])

        #expect(h.animation == .working)
        #expect(h.director.sessions.count == 1)
    }

    @Test func aLiveCompletionHopsThenIdles() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()
        h.settle(agents: [working])

        let status = try #require(h.transport.statusSubscription(for: "w1:p1"))
        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))

        #expect(h.animation == .finished)
        #expect(h.animation(after: 3) == .idle)
    }

    @Test func finishingUnseenInTheBackgroundAlsoCounts() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()
        h.settle(agents: [working])

        try #require(h.transport.statusSubscription(for: "w1:p1")).push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "done"))
        #expect(h.animation == .finished)

        try #require(h.transport.statusSubscription(for: "w1:p1")).push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))
        h.scheduler.advance(by: 5)
        #expect(h.animation == .idle)
    }

    @Test func aReplayedStatusHistoryOnAFreshSubscriptionIsNotACompletion() throws {
        let h = try Harness()
        try h.goLive(agents: [ready])

        let status = try #require(h.transport.statusSubscription(for: "w1:p1"))
        status.acknowledge()
        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "working"))
        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))
        h.scheduler.advance(by: HerdrConnection.flushDelay)

        #expect(h.animation == .idle)
        h.settle(agents: [ready])
        #expect(h.animation == .idle)
    }

    @Test func aQuestionWavesAndAnAnswerResumesWork() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()
        h.settle(agents: [working])
        let status = try #require(h.transport.statusSubscription(for: "w1:p1"))

        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "blocked"))
        #expect(h.animation == .needsYou)
        #expect(h.animation(after: 30) == .needsYou)

        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "working"))
        #expect(h.animation == .working)
    }

    @Test func duplicateStatusEventsChangeNothing() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()
        h.settle(agents: [working])
        let status = try #require(h.transport.statusSubscription(for: "w1:p1"))

        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))
        h.scheduler.advance(by: 5)
        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))

        #expect(h.animation == .idle)
    }

    @Test func aClosedPaneRestsWithoutCelebrating() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()
        h.settle(agents: [working])

        try #require(h.transport.liveLifecycle).push(HerdrFixtures.paneClosed(pane: "w1:p1"))

        #expect(h.animation == .resting)
        #expect(h.transport.statusSubscription(for: "w1:p1") == nil)
    }

    @Test func aNewAgentIsPickedUpThroughDetectionAndReconciliation() throws {
        let h = try Harness()
        try h.goLive(agents: [ready])
        h.armStatusSubscriptions()
        h.settle(agents: [ready])

        let lifecycle = try #require(h.transport.liveLifecycle)
        lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p2", agent: "codex", released: false))
        lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p2", agent: "codex", released: true))
        lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p2", agent: "codex", released: false))

        #expect(h.transport.statusSubscription(for: "w1:p2") != nil)
        #expect(h.transport.pendingSnapshot == nil)
        h.scheduler.advance(by: HerdrConnection.reconcileDelay)
        #expect(h.transport.requests.filter { $0.method == "session.snapshot" }.count == 1)
        h.transport.answerSnapshot(with: [ready, codexWorking])

        #expect(h.animation == .working)
        #expect(h.director.sessions.map(\.identity.paneID).sorted() == ["w1:p1", "w1:p2"])
    }

    @Test func detectionChurnOnAKnownPaneIsIgnored() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()
        h.settle(agents: [working])
        let requestsBefore = h.transport.requests.count

        let lifecycle = try #require(h.transport.liveLifecycle)
        for _ in 0..<5 {
            lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p1", released: true))
            lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p1", released: false))
        }
        h.scheduler.advance(by: 5)

        #expect(h.transport.requests.count == requestsBefore)
        #expect(h.animation == .working)
    }

    @Test func aReconciledCompletionSeenWhileConnectedStillHops() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()

        h.settle(agents: [ready])

        #expect(h.animation == .finished)
    }

    @Test func aReplacedOccupantResetsTheBaseline() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()

        let replacement = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "idle", session: "sess-new", seq: 50)
        h.settle(agents: [replacement])

        #expect(h.animation == .idle)
        #expect(h.director.sessions.first?.identity.agentSession == "sess-new")
    }

    @Test func aMovedPaneIsRelearnedFromTheSnapshot() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()
        h.settle(agents: [working])

        try #require(h.transport.liveLifecycle).push(HerdrFixtures.paneMoved(from: "w1:p1", to: "w2:p1"))
        #expect(h.animation == .resting)

        let moved = HerdrFixtures.agent(pane: "w2:p1", workspace: "w2", tab: "w2:t1", terminal: "term_a", status: "working", session: "sess-a", seq: 60)
        h.settle(agents: [moved])
        #expect(h.animation == .working)
        #expect(h.director.sessions.map(\.identity.paneID) == ["w2:p1"])
    }

    @Test func losingHerdrRestsAndReconnectsWithoutReplayingCelebrations() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()
        h.settle(agents: [working])

        try #require(h.transport.liveLifecycle).close(HerdrTransportError.unreachable("server stopped"))
        #expect(h.animation == .resting)
        #expect(h.transport.subscriptions.allSatisfy { $0.isCancelled })

        h.scheduler.advance(by: HerdrConnection.initialRetryDelay)
        let lifecycle = try #require(h.transport.liveLifecycle)
        lifecycle.acknowledge()
        h.scheduler.advance(by: HerdrConnection.flushDelay)
        h.transport.answerSnapshot(with: [ready])

        #expect(h.animation == .idle)
        #expect(h.animation(after: 0.5) == .idle)
    }

    @Test func retriesBackOffWhileHerdrIsAway() throws {
        let h = try Harness()
        h.connection.start()

        try #require(h.transport.liveLifecycle).close(HerdrTransportError.unreachable("no socket"))
        #expect(h.transport.liveLifecycle == nil)
        h.scheduler.advance(by: 1)
        try #require(h.transport.liveLifecycle).close(HerdrTransportError.unreachable("no socket"))
        h.scheduler.advance(by: 1.9)
        #expect(h.transport.liveLifecycle == nil)
        h.scheduler.advance(by: 0.1)
        #expect(h.transport.liveLifecycle != nil)

        #expect(h.animation == .idle)
        #expect(h.events.isEmpty)
    }

    @Test func aFailedSnapshotIsRetriedQuietly() throws {
        let h = try Harness()
        h.connection.start()
        try #require(h.transport.liveLifecycle).acknowledge()
        h.scheduler.advance(by: HerdrConnection.flushDelay)

        h.transport.failSnapshot()
        #expect(h.events.isEmpty)
        h.scheduler.advance(by: HerdrConnection.initialRetryDelay)
        #expect(h.transport.liveLifecycle != nil)
    }

    @Test func refreshingWithANewSocketPathMovesTheConnection() throws {
        let h = try Harness()
        try h.goLive(agents: [working])

        h.socketPath = "/tmp/other/herdr.sock"
        h.connection.refresh()

        #expect(h.animation == .resting)
        #expect(h.transport.liveLifecycle?.socketPath == "/tmp/other/herdr.sock")
    }

    @Test func refreshingWithTheSamePathChangesNothing() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        let subscriptions = h.transport.subscriptions.count

        h.connection.refresh()

        #expect(h.animation == .working)
        #expect(h.transport.subscriptions.count == subscriptions)
    }

    @Test func activityNeverAsksHerdrToFocusAnything() throws {
        let h = try Harness()
        try h.goLive(agents: [working, codexWorking])
        h.armStatusSubscriptions()
        h.settle(agents: [working, codexWorking])
        let lifecycle = try #require(h.transport.liveLifecycle)

        try #require(h.transport.statusSubscription(for: "w1:p1")).push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "blocked"))
        try #require(h.transport.statusSubscription(for: "w1:p2")).push(HerdrFixtures.statusChanged(pane: "w1:p2", agent: "codex", status: "idle"))
        lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p3", released: false))
        h.scheduler.advance(by: 5)
        h.behavior.setHovering(true, at: h.scheduler.now)
        h.behavior.setHovering(false, at: h.scheduler.now)

        #expect(Set(h.transport.methodsRequested) == ["session.snapshot", "events.subscribe"])
    }

    @Test func stoppingGoesQuietAndStaysQuiet() throws {
        let h = try Harness()
        try h.goLive(agents: [working])
        h.armStatusSubscriptions()

        h.connection.stop()
        h.scheduler.advance(by: 60)

        #expect(h.transport.subscriptions.allSatisfy { $0.isCancelled })
        #expect(h.transport.liveLifecycle == nil)
    }
}
