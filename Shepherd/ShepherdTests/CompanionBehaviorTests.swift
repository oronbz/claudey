import Testing
@testable import Shepherd

struct CompanionBehaviorTests {
    private func behavior() throws -> CompanionBehavior {
        CompanionBehavior(catalog: try AnimationCatalog.bundled(.block), startedAt: 0)
    }

    @Test func restsInIdleUntilSomethingElseIsShown() throws {
        let companion = try behavior()

        #expect(companion.presentation(at: 0).animation == .idle)
        #expect(companion.presentation(at: 30).animation == .idle)
    }

    @Test func everyReactionCanBeShownWithoutASession() throws {
        let companion = try behavior()

        for animation in CompanionAnimation.allCases {
            companion.show(animation, at: 100)
            #expect(companion.presentation(at: 100).animation == animation)
        }
    }

    @Test func workingAdvancesThroughItsConcentrationFrames() throws {
        let companion = try behavior()
        companion.show(.working, at: 10)

        #expect(companion.presentation(at: 10).frameID == 0)
        #expect(companion.presentation(at: 10.7).frameID == 1)
        #expect(companion.presentation(at: 11.4).frameID == 0)
    }

    @Test func aCompletionHopReturnsToTheOngoingState() throws {
        let companion = try behavior()
        companion.show(.working, at: 0)
        companion.show(.finished, at: 5)

        #expect(companion.presentation(at: 5).animation == .finished)
        #expect(companion.presentation(at: 5.5).animation == .finished)
        #expect(companion.presentation(at: 7).animation == .working)
    }

    @Test func needsYouHoldsItsQuestioningPose() throws {
        let companion = try behavior()
        companion.show(.needsYou, at: 0)

        #expect(companion.presentation(at: 60).animation == .needsYou)
        #expect(companion.presentation(at: 60).frameID == 2)
    }

    @Test func hoveringPlaysTheHappyReactionAndThenRestoresTheState() throws {
        let companion = try behavior()
        companion.show(.working, at: 0)

        companion.setHovering(true, at: 1)
        #expect(companion.presentation(at: 1).animation == .hover)
        #expect(companion.presentation(at: 1).frameID == 0)

        companion.setHovering(false, at: 2)
        #expect(companion.presentation(at: 2).animation == .working)
        #expect(companion.presentation(at: 2).frameID == 0)
    }

    @Test func hoveringDuringACompletionKeepsTheCelebration() throws {
        let companion = try behavior()
        companion.show(.working, at: 0)
        companion.show(.finished, at: 1)

        companion.setHovering(true, at: 1.2)
        companion.setHovering(false, at: 1.4)

        #expect(companion.presentation(at: 1.5).animation == .finished)
        #expect(companion.presentation(at: 2.1).animation == .working)
    }

    @Test func hoveringDoesNotDisturbTheUnderlyingState() throws {
        let companion = try behavior()
        companion.show(.needsYou, at: 0)
        companion.setHovering(true, at: 1)
        companion.setHovering(false, at: 2)

        #expect(companion.presentation(at: 5).animation == .needsYou)
    }

    @Test func schedulesARedrawWhenTheNextFrameIsDue() throws {
        let companion = try behavior()
        companion.show(.working, at: 0)

        #expect(abs((companion.timeUntilNextFrame(at: 0) ?? 0) - 0.65) < 1e-9)
        #expect(abs((companion.timeUntilNextFrame(at: 0.4) ?? 0) - 0.25) < 1e-9)
    }

    @Test func switchingAvatarKeepsTheReactionInProgress() throws {
        let companion = try behavior()
        companion.show(.working, at: 0)
        companion.show(.finished, at: 5)

        companion.use(try AnimationCatalog.bundled(.softSpark))

        #expect(companion.presentation(at: 5.2).animation == .finished)
        #expect(companion.presentation(at: 7).animation == .working)
        #expect(companion.presentation(at: 7.7).frameID == 1)
    }

    @Test func aHeldPoseStopsAskingForRedraws() throws {
        let companion = try behavior()
        companion.show(.resting, at: 0)

        #expect(companion.timeUntilNextFrame(at: 3) == nil)
    }
}
