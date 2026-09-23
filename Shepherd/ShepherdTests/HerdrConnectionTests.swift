import Foundation
import Testing
@testable import Shepherd

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
            behavior = CompanionBehavior(catalog: try AnimationCatalog.bundled(.block), startedAt: 0)
            director = CompanionDirector(behavior: behavior, startedAt: 0)
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

        func goLive(agents: [String]) throws {
            connection.start()
            let lifecycle = try #require(transport.liveLifecycle)
            lifecycle.acknowledge()
            scheduler.advance(by: HerdrConnection.flushDelay)
            transport.answerSnapshot(with: agents)
        }

        func armStatusSubscriptions() {
            for subscription in transport.subscriptions where !subscription.isCancelled && subscription.paneID != nil {
                subscription.acknowledge()
            }
            scheduler.advance(by: HerdrConnection.flushDelay)
        }

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
        let harness = try Harness()
        harness.connection.start()

        #expect(harness.animation == .resting)
        let lifecycle = try #require(harness.transport.liveLifecycle)
        #expect(lifecycle.types.map { $0["type"]! }.sorted() == ["pane.agent_detected", "pane.closed", "pane.exited", "pane.moved"])
        #expect(harness.transport.pendingSnapshot == nil)

        lifecycle.acknowledge()
        harness.scheduler.advance(by: HerdrConnection.flushDelay)
        #expect(harness.transport.pendingSnapshot != nil)

        harness.transport.answerSnapshot(with: [working])
        #expect(harness.animation == .working)
        #expect(harness.transport.statusSubscription(for: "w1:p1") != nil)
    }

    @Test func aQuietInitialSnapshotNeverCelebrates() throws {
        let harness = try Harness()
        try harness.goLive(agents: [ready, done])

        #expect(harness.animation == .idle)
        #expect(harness.animation(after: 0.2) == .idle)
    }

    @Test func replayedEventsBeforeTheBaselineAreIgnored() throws {
        let harness = try Harness()
        harness.connection.start()
        let lifecycle = try #require(harness.transport.liveLifecycle)
        lifecycle.acknowledge()
        lifecycle.push(HerdrFixtures.paneClosed(pane: "w1:p1"))
        harness.scheduler.advance(by: HerdrConnection.flushDelay)
        harness.transport.answerSnapshot(with: [working])

        #expect(harness.animation == .working)
        #expect(harness.director.sessions.count == 1)
    }

    @Test func aLiveCompletionHopsThenIdles() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])

        let status = try #require(harness.transport.statusSubscription(for: "w1:p1"))
        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))

        #expect(harness.animation == .finished)
        #expect(harness.animation(after: 3) == .idle)
    }

    @Test func finishingUnseenInTheBackgroundAlsoCounts() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])

        try #require(harness.transport.statusSubscription(for: "w1:p1")).push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "done"))
        #expect(harness.animation == .finished)

        try #require(harness.transport.statusSubscription(for: "w1:p1")).push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))
        harness.scheduler.advance(by: 5)
        #expect(harness.animation == .idle)
    }

    @Test func aReplayedStatusHistoryOnAFreshSubscriptionIsNotACompletion() throws {
        let harness = try Harness()
        try harness.goLive(agents: [ready])

        let status = try #require(harness.transport.statusSubscription(for: "w1:p1"))
        status.acknowledge()
        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "working"))
        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))
        harness.scheduler.advance(by: HerdrConnection.flushDelay)

        #expect(harness.animation == .idle)
        harness.settle(agents: [ready])
        #expect(harness.animation == .idle)
    }

    @Test func aQuestionWavesAndAnAnswerResumesWork() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])
        let status = try #require(harness.transport.statusSubscription(for: "w1:p1"))

        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "blocked"))
        #expect(harness.animation == .needsYou)
        #expect(harness.animation(after: 30) == .needsYou)

        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "working"))
        #expect(harness.animation == .working)
    }

    @Test func duplicateStatusEventsChangeNothing() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])
        let status = try #require(harness.transport.statusSubscription(for: "w1:p1"))

        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))
        harness.scheduler.advance(by: 5)
        status.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))

        #expect(harness.animation == .idle)
    }

    @Test func aClosedPaneRestsWithoutCelebrating() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])

        try #require(harness.transport.liveLifecycle).push(HerdrFixtures.paneClosed(pane: "w1:p1"))

        #expect(harness.animation == .resting)
        #expect(harness.transport.statusSubscription(for: "w1:p1") == nil)
    }

    @Test func aNewAgentIsPickedUpThroughDetectionAndReconciliation() throws {
        let harness = try Harness()
        try harness.goLive(agents: [ready])
        harness.armStatusSubscriptions()
        harness.settle(agents: [ready])

        let lifecycle = try #require(harness.transport.liveLifecycle)
        lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p2", agent: "codex", released: false))
        lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p2", agent: "codex", released: true))
        lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p2", agent: "codex", released: false))

        #expect(harness.transport.statusSubscription(for: "w1:p2") != nil)
        #expect(harness.transport.pendingSnapshot == nil)
        harness.scheduler.advance(by: HerdrConnection.reconcileDelay)
        #expect(harness.transport.requests.filter { $0.method == "session.snapshot" }.count == 1)
        harness.transport.answerSnapshot(with: [ready, codexWorking])

        #expect(harness.animation == .working)
        #expect(harness.director.sessions.map(\.identity.paneID).sorted() == ["w1:p1", "w1:p2"])
    }

    @Test func detectionChurnOnAKnownPaneCoalescesIntoOneReconcile() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])
        let requestsBefore = harness.transport.requests.count

        let lifecycle = try #require(harness.transport.liveLifecycle)
        for _ in 0..<5 {
            lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p1", released: true))
            lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p1", released: false))
        }
        harness.scheduler.advance(by: 5)

        #expect(harness.transport.requests.count == requestsBefore + 1)
        harness.transport.answerSnapshot(with: [working])
        #expect(harness.animation == .working)
        #expect(harness.transport.subscriptions.filter { $0.paneID == "w1:p1" && !$0.isCancelled }.count == 1)
    }

    @Test func anAgentThatExitsButLeavesItsShellIsForgotten() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])

        try #require(harness.transport.liveLifecycle).push(HerdrFixtures.agentDetected(pane: "w1:p1", released: true))
        harness.settle(agents: [])

        #expect(harness.animation == .resting)
        #expect(harness.director.sessions.isEmpty)
    }

    @Test func aStatusEventFromADifferentOccupantDoesNotHop() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])

        try #require(harness.transport.statusSubscription(for: "w1:p1"))
            .push(HerdrFixtures.statusChanged(pane: "w1:p1", agent: "codex", status: "idle"))
        #expect(harness.animation == .working)

        let replacement = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", agent: "codex", status: "idle", session: "sess-x", seq: 9)
        harness.settle(agents: [replacement])
        #expect(harness.animation == .idle)
    }

    @Test func aReconciledCompletionSeenWhileConnectedStillHops() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()

        harness.settle(agents: [ready])

        #expect(harness.animation == .finished)
    }

    @Test func aReplacedOccupantResetsTheBaseline() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()

        let replacement = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "idle", session: "sess-new", seq: 50)
        harness.settle(agents: [replacement])

        #expect(harness.animation == .idle)
        #expect(harness.director.sessions.first?.identity.agentSession == "sess-new")
    }

    @Test func aMovedPaneIsRelearnedFromTheSnapshot() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])

        try #require(harness.transport.liveLifecycle).push(HerdrFixtures.paneMoved(from: "w1:p1", to: "w2:p1"))
        #expect(harness.animation == .resting)

        let moved = HerdrFixtures.agent(pane: "w2:p1", workspace: "w2", tab: "w2:t1", terminal: "term_a", status: "working", session: "sess-a", seq: 60)
        harness.settle(agents: [moved])
        #expect(harness.animation == .working)
        #expect(harness.director.sessions.map(\.identity.paneID) == ["w2:p1"])
    }

    @Test func losingHerdrRestsAndReconnectsWithoutReplayingCelebrations() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])

        try #require(harness.transport.liveLifecycle).close(HerdrTransportError.unreachable("server stopped"))
        #expect(harness.animation == .resting)
        #expect(harness.transport.subscriptions.allSatisfy { $0.isCancelled })

        harness.scheduler.advance(by: HerdrConnection.initialRetryDelay)
        let lifecycle = try #require(harness.transport.liveLifecycle)
        lifecycle.acknowledge()
        harness.scheduler.advance(by: HerdrConnection.flushDelay)
        harness.transport.answerSnapshot(with: [ready])

        #expect(harness.animation == .idle)
        #expect(harness.animation(after: 0.5) == .idle)
    }

    @Test func retriesBackOffWhileHerdrIsAway() throws {
        let harness = try Harness()
        harness.connection.start()

        try #require(harness.transport.liveLifecycle).close(HerdrTransportError.unreachable("no socket"))
        #expect(harness.transport.liveLifecycle == nil)
        harness.scheduler.advance(by: 1)
        try #require(harness.transport.liveLifecycle).close(HerdrTransportError.unreachable("no socket"))
        harness.scheduler.advance(by: 1.9)
        #expect(harness.transport.liveLifecycle == nil)
        harness.scheduler.advance(by: 0.1)
        #expect(harness.transport.liveLifecycle != nil)

        #expect(harness.animation == .resting)
        #expect(harness.events.isEmpty)
    }

    @Test func aFailedSnapshotIsRetriedQuietly() throws {
        let harness = try Harness()
        harness.connection.start()
        try #require(harness.transport.liveLifecycle).acknowledge()
        harness.scheduler.advance(by: HerdrConnection.flushDelay)

        harness.transport.failSnapshot()
        #expect(harness.events.isEmpty)
        harness.scheduler.advance(by: HerdrConnection.initialRetryDelay)
        #expect(harness.transport.liveLifecycle != nil)
    }

    @Test func refreshingWithANewSocketPathMovesTheConnection() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])

        harness.socketPath = "/tmp/other/herdr.sock"
        harness.connection.refresh()

        #expect(harness.animation == .resting)
        #expect(harness.transport.liveLifecycle?.socketPath == "/tmp/other/herdr.sock")
    }

    @Test func refreshingWithTheSamePathChangesNothing() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        let subscriptions = harness.transport.subscriptions.count

        harness.connection.refresh()

        #expect(harness.animation == .working)
        #expect(harness.transport.subscriptions.count == subscriptions)
    }

    @Test func activityNeverAsksHerdrToFocusAnything() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working, codexWorking])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working, codexWorking])
        let lifecycle = try #require(harness.transport.liveLifecycle)

        try #require(harness.transport.statusSubscription(for: "w1:p1")).push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "blocked"))
        try #require(harness.transport.statusSubscription(for: "w1:p2")).push(HerdrFixtures.statusChanged(pane: "w1:p2", agent: "codex", status: "idle"))
        lifecycle.push(HerdrFixtures.agentDetected(pane: "w1:p3", released: false))
        harness.scheduler.advance(by: 5)
        harness.behavior.setHovering(true, at: harness.scheduler.now)
        harness.behavior.setHovering(false, at: harness.scheduler.now)

        #expect(Set(harness.transport.methodsRequested) == ["session.snapshot", "events.subscribe"])
    }

    @Test func stoppingGoesQuietAndStaysQuiet() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()

        harness.connection.stop()

        #expect(harness.animation == .resting)
        #expect(harness.events.last == .disconnected)
        harness.scheduler.advance(by: 60)

        #expect(harness.transport.subscriptions.allSatisfy { $0.isCancelled })
        #expect(harness.transport.liveLifecycle == nil)
    }

    @Test func stoppingBeforeGoingLiveSaysNothing() throws {
        let harness = try Harness()
        harness.connection.start()

        harness.connection.stop()

        #expect(harness.events.isEmpty)
    }

    @Test func focusingAPaneAsksHerdrForExactlyThatPane() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        var outcomes: [Bool] = []

        harness.connection.focusPane("w1:p1") { outcomes.append($0) }

        let request = try #require(harness.transport.requests.last)
        #expect(request.method == "pane.focus")
        #expect(request.params["pane_id"] as? String == "w1:p1")
        harness.transport.answerLastRequest(with: HerdrFixtures.paneFocused(id: request.id, pane: "w1:p1"))
        #expect(outcomes == [true])
    }

    @Test func aPaneHerdrNoLongerKnowsCannotBeFocused() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        var outcomes: [Bool] = []

        harness.connection.focusPane("w1:p1") { outcomes.append($0) }

        let request = try #require(harness.transport.requests.last)
        harness.transport.answerLastRequest(with: HerdrFixtures.error(id: request.id, code: "pane_not_found", message: "pane w1:p1 not found"))
        #expect(outcomes == [false])
    }

    @Test func focusingWithoutAConnectionFailsWithoutAsking() throws {
        let harness = try Harness()
        var outcomes: [Bool] = []

        harness.connection.focusPane("w1:p1") { outcomes.append($0) }

        #expect(outcomes == [false])
        #expect(harness.transport.requests.isEmpty)
    }

    @Test func reconnectingWithTwoSessionsResumesThemAndOnlyLaterTransitionsHop() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working, codexWorking])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working, codexWorking])

        try #require(harness.transport.liveLifecycle).close(HerdrTransportError.unreachable("server stopped"))
        #expect(harness.animation == .resting)

        harness.scheduler.advance(by: HerdrConnection.initialRetryDelay)
        let lifecycle = try #require(harness.transport.liveLifecycle)
        lifecycle.acknowledge()
        harness.scheduler.advance(by: HerdrConnection.flushDelay)
        let codexBlocked = HerdrFixtures.agent(pane: "w1:p2", terminal: "term_b", agent: "codex", status: "blocked", session: "sess-b", seq: 43)
        harness.transport.answerSnapshot(with: [ready, codexBlocked])

        #expect(harness.animation == .needsYou)
        #expect(harness.director.clickTarget(at: harness.scheduler.now)?.paneID == "w1:p2")
        #expect(harness.transport.statusSubscription(for: "w1:p1") != nil)
        #expect(harness.transport.statusSubscription(for: "w1:p2") != nil)

        harness.armStatusSubscriptions()
        harness.settle(agents: [ready, codexBlocked])
        try #require(harness.transport.statusSubscription(for: "w1:p2")).push(HerdrFixtures.statusChanged(pane: "w1:p2", agent: "codex", status: "working"))
        #expect(harness.animation == .working)
        try #require(harness.transport.statusSubscription(for: "w1:p2")).push(HerdrFixtures.statusChanged(pane: "w1:p2", agent: "codex", status: "idle"))
        #expect(harness.animation == .finished)
        #expect(harness.director.clickTarget(at: harness.scheduler.now)?.paneID == "w1:p2")
    }

    @Test func linesFromTheLostConnectionChangeNothingAfterReconnecting() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working])
        let stale = try #require(harness.transport.statusSubscription(for: "w1:p1"))
        let staleLifecycle = try #require(harness.transport.liveLifecycle)

        staleLifecycle.close(HerdrTransportError.unreachable("server stopped"))
        harness.scheduler.advance(by: HerdrConnection.initialRetryDelay)
        try #require(harness.transport.liveLifecycle).acknowledge()
        harness.scheduler.advance(by: HerdrConnection.flushDelay)
        harness.transport.answerSnapshot(with: [working])
        let eventsBefore = harness.events.count

        stale.push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "idle"))
        staleLifecycle.push(HerdrFixtures.paneClosed(pane: "w1:p1"))
        staleLifecycle.close(nil)

        #expect(harness.events.count == eventsBefore)
        #expect(harness.animation == .working)
        #expect(harness.transport.liveLifecycle != nil)
    }

    @Test func aSecondQuestionKeepsTheClickOnTheFirstUntilItIsAnswered() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working, codexWorking])
        harness.armStatusSubscriptions()
        harness.settle(agents: [working, codexWorking])

        try #require(harness.transport.statusSubscription(for: "w1:p2")).push(HerdrFixtures.statusChanged(pane: "w1:p2", agent: "codex", status: "blocked"))
        try #require(harness.transport.statusSubscription(for: "w1:p1")).push(HerdrFixtures.statusChanged(pane: "w1:p1", status: "blocked"))
        #expect(harness.director.clickTarget(at: harness.scheduler.now)?.paneID == "w1:p2")

        try #require(harness.transport.statusSubscription(for: "w1:p2")).push(HerdrFixtures.statusChanged(pane: "w1:p2", agent: "codex", status: "working"))
        #expect(harness.animation == .needsYou)
        #expect(harness.director.clickTarget(at: harness.scheduler.now)?.paneID == "w1:p1")
    }
}
