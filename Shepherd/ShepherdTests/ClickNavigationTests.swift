import Foundation
import Testing
@testable import Shepherd

struct ClickNavigationTests {
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

    private final class Harness {
        let behavior: CompanionBehavior
        let director: CompanionDirector
        let host = FakeNavigationHost()
        let navigator: ClickNavigator
        var outcomes: [NavigationOutcome] = []

        init() throws {
            behavior = CompanionBehavior(catalog: try AnimationCatalog.bundled(.block), startedAt: 0)
            director = CompanionDirector(behavior: behavior, startedAt: 0)
            navigator = ClickNavigator(director: director, host: host)
            navigator.onOutcome = { [unowned self] in outcomes.append($0) }
        }

        func connected(_ records: [SessionRecord], at now: TimeInterval = 0) {
            director.apply(.connected(records), at: now)
        }

        func animation(at now: TimeInterval) -> CompanionAnimation {
            behavior.presentation(at: now).animation
        }
    }

    @Test func activityAndHoverNeverNavigate() throws {
        let harness = try Harness()
        harness.connected([.init(identity: claude, status: .working)])

        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 1)
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 2)
        harness.behavior.setHovering(true, at: 3)
        harness.behavior.setHovering(false, at: 4)

        #expect(harness.host.focusedPanes.isEmpty)
        #expect(harness.host.terminalActivations == 0)
    }

    @Test func clickingGoesToTheWorkingSessionAndBringsItsTerminalForward() throws {
        let harness = try Harness()
        harness.connected([.init(identity: claude, status: .working)])

        harness.navigator.click(at: 1)

        #expect(harness.host.focusedPanes == [claude.paneID])
        #expect(harness.host.terminalActivations == 1)
        #expect(harness.outcomes == [.focusedPane(claude.paneID)])
    }

    @Test func aSessionNeedingYouWinsOverAWorkingOne() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)

        harness.navigator.click(at: 2)

        #expect(harness.host.focusedPanes == [codex.paneID])
    }

    @Test func theMostRecentlyAskedRemainingQuestionWinsOnceThePinnedOneIsAnswered() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
            .init(identity: sibling, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 2)
        harness.director.apply(.statusChanged(paneID: sibling.paneID, status: .needsYou), at: 3)
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .working), at: 4)

        harness.navigator.click(at: 5)

        #expect(harness.host.focusedPanes == [sibling.paneID])
    }

    @Test func clickingTheHopOpensTheSessionThatJustFinished() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 10)

        harness.navigator.click(at: 10.5)

        #expect(harness.host.focusedPanes == [claude.paneID])
    }

    @Test func afterTheHopAnOrdinaryClickGoesToTheMostRecentlyActiveSession() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 10)
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .ready), at: 11)
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .working), at: 12)

        harness.navigator.click(at: 20)

        #expect(harness.host.focusedPanes == [codex.paneID])
    }

    @Test func aHopHiddenBehindNeedsYouStillTargetsTheQuestion() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .needsYou),
        ])
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)

        harness.navigator.click(at: 1.2)

        #expect(harness.host.focusedPanes == [codex.paneID])
    }

    @Test func twoPanesInOneProjectStayDistinct() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: sibling, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: sibling.paneID, status: .ready), at: 1)

        harness.navigator.click(at: 1.5)

        #expect(harness.host.focusedPanes == [sibling.paneID])
    }

    @Test func aFinishedSessionThatVanishedDoesNotSendYouElsewhere() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)
        harness.director.apply(.sessionRemoved(paneID: claude.paneID), at: 1.2)

        harness.navigator.click(at: 1.5)

        #expect(harness.host.focusedPanes.isEmpty)
        #expect(harness.host.terminalActivations == 1)
        #expect(harness.outcomes == [.activatedHost])
    }

    @Test func aReplacedOccupantIsNotTheSessionThatFinished() throws {
        let harness = try Harness()
        harness.connected([.init(identity: claude, status: .working)])
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)
        let replacement = SessionIdentity(
            paneID: claude.paneID, terminalID: claude.terminalID, workspaceID: claude.workspaceID,
            tabID: claude.tabID, agent: "claude", agentSession: "sess-z"
        )
        harness.director.apply(.sessionAppeared(.init(identity: replacement, status: .ready)), at: 1.2)

        harness.navigator.click(at: 1.5)

        #expect(harness.host.focusedPanes.isEmpty)
        #expect(harness.outcomes == [.activatedHost])
    }

    @Test func aPaneGoneAtNavigationTimeFallsBackToTheHost() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .ready),
        ])
        harness.host.paneExists = { _ in false }

        harness.navigator.click(at: 1)

        #expect(harness.host.focusedPanes == [claude.paneID])
        #expect(harness.host.terminalActivations == 1)
        #expect(harness.outcomes == [.activatedHost])
    }

    @Test func nothingToShowActivatesTheKnownHost() throws {
        let harness = try Harness()
        harness.connected([])

        harness.navigator.click(at: 1)

        #expect(harness.host.focusedPanes.isEmpty)
        #expect(harness.outcomes == [.activatedHost])
    }

    @Test func withNoReliableTargetHeReactsPlayfullyInstead() throws {
        let harness = try Harness()
        harness.host.terminalReachable = false

        harness.navigator.click(at: 1)

        #expect(harness.outcomes == [.unavailable])
        #expect(harness.animation(at: 1) == .hover)
        #expect(harness.animation(at: 1.5) == .hover)
        #expect(harness.animation(at: 3) == .resting)
    }

    @Test func aSecondClickWhileHerdrIsStillAnsweringIsIgnored() throws {
        let harness = try Harness()
        harness.connected([.init(identity: claude, status: .working)])
        harness.host.answersImmediately = false

        harness.navigator.click(at: 1)
        harness.navigator.click(at: 1.1)
        harness.host.answerPending()

        #expect(harness.host.focusedPanes == [claude.paneID])
        #expect(harness.outcomes == [.focusedPane(claude.paneID)])

        harness.navigator.click(at: 5)
        harness.host.answerPending()
        #expect(harness.host.focusedPanes == [claude.paneID, claude.paneID])
    }

    @Test func disconnectedHerdrLeavesNoSessionTarget() throws {
        let harness = try Harness()
        harness.connected([.init(identity: claude, status: .working)])
        harness.director.apply(.disconnected, at: 1)

        harness.navigator.click(at: 2)

        #expect(harness.host.focusedPanes.isEmpty)
    }

    @Test func aSecondQuestionMidPoseKeepsTheClickOnTheFirst() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 2)

        harness.navigator.click(at: 3)

        #expect(harness.host.focusedPanes == [codex.paneID])
    }

    @Test func aRepeatedQuestionEventNeitherRetargetsNorWavesAgain() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 2)
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 3)

        harness.navigator.click(at: 3.1)

        #expect(harness.host.focusedPanes == [codex.paneID])
        #expect(harness.behavior.presentation(at: 3.1).frameID == 2)
    }

    @Test func answeringThePinnedQuestionMovesTheClickToTheNextOne() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 2)
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .working), at: 4)

        harness.navigator.click(at: 5)

        #expect(harness.host.focusedPanes == [claude.paneID])
        #expect(harness.animation(at: 5) == .needsYou)
    }

    @Test func aPinnedQuestionWhosePaneClosesMovesToTheRemainingOne() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 2)
        harness.director.apply(.sessionRemoved(paneID: codex.paneID), at: 4)

        harness.navigator.click(at: 5)

        #expect(harness.host.focusedPanes == [claude.paneID])
    }

    @Test func aPinnedQuestionWhoseOccupantChangesMovesToTheRemainingOne() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 2)
        let replacement = SessionIdentity(
            paneID: codex.paneID, terminalID: codex.terminalID, workspaceID: codex.workspaceID,
            tabID: codex.tabID, agent: "codex", agentSession: "sess-z"
        )
        harness.director.apply(.sessionAppeared(.init(identity: replacement, status: .working)), at: 4)

        harness.navigator.click(at: 5)

        #expect(harness.host.focusedPanes == [claude.paneID])
    }

    @Test func aQuestionAskedAfterThePoseEndedIsPinnedAfresh() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .working), at: 2)
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .needsYou), at: 3)
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 4)

        harness.navigator.click(at: 5)

        #expect(harness.host.focusedPanes == [claude.paneID])
    }

    @Test func aReconnectPinsWhateverHerdrNowReportsAsWaiting() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .needsYou), at: 1)
        harness.director.apply(.disconnected, at: 2)
        harness.connected([
            .init(identity: claude, status: .needsYou),
            .init(identity: codex, status: .working),
        ], at: 3)

        harness.navigator.click(at: 4)

        #expect(harness.host.focusedPanes == [claude.paneID])
    }

    @Test func clickingTheLatestOfTwoQuickHopsOpensTheLatestFinishedSession() throws {
        let harness = try Harness()
        harness.connected([
            .init(identity: claude, status: .working),
            .init(identity: codex, status: .working),
            .init(identity: sibling, status: .working),
        ])
        harness.director.apply(.statusChanged(paneID: claude.paneID, status: .ready), at: 1)
        harness.director.apply(.statusChanged(paneID: codex.paneID, status: .ready), at: 1.2)

        harness.navigator.click(at: 1.5)

        #expect(harness.host.focusedPanes == [codex.paneID])
        #expect(harness.animation(at: 1.5) == .finished)
        #expect(harness.animation(at: 6) == .working)
    }
}
