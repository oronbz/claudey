import Testing
@testable import Claudey

struct ActivityDirectorTests {
    private let claude = SessionIdentity(
        paneID: "w1:p1", terminalID: "term_a", workspaceID: "w1", tabID: "w1:t1",
        agent: "claude", agentSession: "sess-a"
    )
    private let codex = SessionIdentity(
        paneID: "w1:p2", terminalID: "term_b", workspaceID: "w1", tabID: "w1:t1",
        agent: "codex", agentSession: "sess-b"
    )
    private let sibling = SessionIdentity(
        paneID: "w1:p3", terminalID: "term_c", workspaceID: "w1", tabID: "w1:t2",
        agent: "claude", agentSession: "sess-c"
    )

    private func director() throws -> (CompanionDirector, CompanionBehavior) {
        let behavior = CompanionBehavior(catalog: try AnimationCatalog.bundled(), startedAt: 0)
        return (CompanionDirector(behavior: behavior, startedAt: 0), behavior)
    }

    @Test func restsUntilHerdrIsReached() throws {
        let (_, behavior) = try director()

        #expect(behavior.presentation(at: 0).animation == .resting)
        #expect(behavior.presentation(at: 30).animation == .resting)
    }

    @Test func restsWhileDisconnected() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .ready)]), at: 0)

        director.apply(.disconnected, at: 1)

        #expect(behavior.presentation(at: 1).animation == .resting)
    }

    @Test func aQuietSnapshotIdlesWithoutCelebrating() throws {
        let (director, behavior) = try director()

        director.apply(.connected([.init(identity: claude, status: .ready)]), at: 1)

        #expect(behavior.presentation(at: 1).animation == .idle)
        #expect(behavior.presentation(at: 1.3).animation == .idle)
    }

    @Test func noAgentsMeansRest() throws {
        let (director, behavior) = try director()

        director.apply(.connected([]), at: 1)

        #expect(behavior.presentation(at: 1).animation == .resting)
    }

    @Test func aWorkingSessionConcentrates() throws {
        let (director, behavior) = try director()

        director.apply(.connected([.init(identity: claude, status: .working)]), at: 1)

        #expect(behavior.presentation(at: 1).animation == .working)
    }

    @Test func finishingHopsThenSettlesToIdle() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .working)]), at: 0)

        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 10)

        #expect(behavior.presentation(at: 10).animation == .finished)
        #expect(behavior.presentation(at: 10.5).animation == .finished)
        #expect(behavior.presentation(at: 13).animation == .idle)
    }

    @Test func aDuplicateReadyEventDoesNotHopAgain() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .working)]), at: 0)
        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 10)

        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 20)

        #expect(behavior.presentation(at: 20).animation == .idle)
    }

    @Test func needsYouWavesAndHoldsOverAWorkingSibling() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ]), at: 0)

        director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)

        #expect(behavior.presentation(at: 1).animation == .needsYou)
        #expect(behavior.presentation(at: 60).animation == .needsYou)
        #expect(behavior.presentation(at: 60).frameID == 12)
    }

    @Test func aCompletionDoesNotInterruptAHeldNeedsYou() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .needsYou),
        ]), at: 0)

        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)

        #expect(behavior.presentation(at: 1).animation == .needsYou)
        #expect(behavior.presentation(at: 1.5).animation == .needsYou)
    }

    @Test func aCompletionIsAcknowledgedWhileAnotherSessionKeepsWorking() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ]), at: 0)

        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)

        #expect(behavior.presentation(at: 1).animation == .finished)
        #expect(behavior.presentation(at: 4).animation == .working)
    }

    @Test func answeringAQuestionReturnsToWorkWithoutAHop() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .needsYou)]), at: 0)

        director.apply(.statusChanged(paneID: claude.paneID, status: .working), at: 1)
        #expect(behavior.presentation(at: 1).animation == .working)

        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 2)
        #expect(behavior.presentation(at: 2).animation == .finished)
    }

    @Test func dismissingAQuestionDoesNotCountAsFinishing() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .needsYou)]), at: 0)

        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)

        #expect(behavior.presentation(at: 1).animation == .idle)
    }

    @Test func anUncertainSessionRestsAndNeverCelebrates() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .working)]), at: 0)

        director.apply(.statusChanged(paneID: claude.paneID, status: .uncertain), at: 1)
        #expect(behavior.presentation(at: 1).animation == .resting)

        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 2)
        #expect(behavior.presentation(at: 2).animation == .idle)
    }

    @Test func anUncertainSessionDoesNotHideAWorkingOne() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .uncertain),
        ]), at: 0)

        #expect(behavior.presentation(at: 0).animation == .working)
    }

    @Test func aRemovedWorkingSessionRestsInsteadOfCelebrating() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .working)]), at: 0)

        director.apply(.sessionRemoved(paneID: claude.paneID), at: 1)

        #expect(behavior.presentation(at: 1).animation == .resting)
    }

    @Test func aDisconnectMidWorkIsNotACompletion() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .working)]), at: 0)

        director.apply(.disconnected, at: 1)
        #expect(behavior.presentation(at: 1).animation == .resting)

        director.apply(.connected([.init(identity: claude, status: .ready)]), at: 2)
        #expect(behavior.presentation(at: 2).animation == .idle)
    }

    @Test func aReplacedOccupantStartsFresh() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .working)]), at: 0)

        let replacement = SessionIdentity(
            paneID: claude.paneID, terminalID: claude.terminalID, workspaceID: claude.workspaceID,
            tabID: claude.tabID, agent: "claude", agentSession: "sess-z"
        )
        director.apply(.sessionAppeared(.init(identity: replacement, status: .ready)), at: 1)

        #expect(behavior.presentation(at: 1).animation == .idle)
    }

    @Test func twoSessionsInOneProjectStayDistinct() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: sibling, status: .working),
        ]), at: 0)

        director.apply(.statusChanged(paneID: sibling.paneID, status: .ready), at: 1)

        #expect(behavior.presentation(at: 1).animation == .finished)
        #expect(behavior.presentation(at: 4).animation == .working)
        #expect(director.sessions.map(\.identity.paneID).sorted() == ["w1:p1", "w1:p3"])
    }

    @Test func hoveringStillWinsOverActivity() throws {
        let (director, behavior) = try director()
        director.apply(.connected([.init(identity: claude, status: .working)]), at: 0)

        behavior.setHovering(true, at: 1)
        director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 2)
        #expect(behavior.presentation(at: 2).animation == .hover)

        behavior.setHovering(false, at: 3)
        #expect(behavior.presentation(at: 3).animation == .needsYou)
    }

    @Test func aCompletionHiddenBehindAQuestionIsNotReplayedWhenItIsAnswered() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .needsYou),
        ]), at: 0)
        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)

        director.apply(.statusChanged(paneID: codex.paneID, status: .working), at: 2)

        #expect(behavior.presentation(at: 2).animation == .working)
        #expect(behavior.presentation(at: 2.5).animation == .working)
    }

    @Test func aQuestionArrivingMidHopTakesOverWithoutAStaleHopAfterwards() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ]), at: 0)
        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)

        director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1.5)
        #expect(behavior.presentation(at: 1.5).animation == .needsYou)

        director.apply(.statusChanged(paneID: codex.paneID, status: .working), at: 2)
        #expect(behavior.presentation(at: 2).animation == .working)
        #expect(behavior.presentation(at: 2.5).animation == .working)
    }

    @Test func aReconnectSnapshotResumesTheAggregateWithoutHistoricalHops() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ]), at: 0)
        director.apply(.disconnected, at: 1)

        director.apply(.connected([
            .init(identity: claude, status: .ready),
            .init(identity: codex, status: .working),
        ]), at: 2)
        #expect(behavior.presentation(at: 2).animation == .working)
        #expect(behavior.presentation(at: 2.5).animation == .working)

        director.apply(.statusChanged(paneID: codex.paneID, status: .ready), at: 3)
        #expect(behavior.presentation(at: 3).animation == .finished)
    }

    @Test func aSessionThatTurnsUncertainDoesNotHopWhenItSettles() throws {
        let (director, behavior) = try director()
        director.apply(.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ]), at: 0)

        director.apply(.statusChanged(paneID: claude.paneID, status: .uncertain), at: 1)
        #expect(behavior.presentation(at: 1).animation == .working)

        director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 2)
        #expect(behavior.presentation(at: 2).animation == .working)
        #expect(behavior.presentation(at: 2.5).animation == .working)
    }
}
