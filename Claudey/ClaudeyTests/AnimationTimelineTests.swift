import Testing
@testable import Claudey

struct AnimationTimelineTests {
    private let loop = AnimationTimeline(
        playback: .loop,
        steps: [.init(index: 3, durationMs: 200), .init(index: 4, durationMs: 300)]
    )

    @Test func loopingHoldsEachFrameForItsDuration() {
        #expect(loop.frame(at: 0) == 3)
        #expect(loop.frame(at: 0.199) == 3)
        #expect(loop.frame(at: 0.2) == 4)
        #expect(loop.frame(at: 0.499) == 4)
    }

    @Test func loopingRepeatsFromTheStart() {
        #expect(loop.frame(at: 0.5) == 3)
        #expect(loop.frame(at: 0.75) == 4)
        #expect(loop.frame(at: 5.0) == 3)
    }

    @Test func loopingNeverReportsCompletion() {
        #expect(loop.hasCompleted(at: 99) == false)
    }

    @Test func holdingKeepsTheFinalFrame() {
        let hold = AnimationTimeline(
            playback: .hold,
            steps: [.init(index: 9, durationMs: 100), .init(index: 12, durationMs: 100)]
        )

        #expect(hold.frame(at: 0) == 9)
        #expect(hold.frame(at: 0.15) == 12)
        #expect(hold.frame(at: 600) == 12)
        #expect(hold.hasCompleted(at: 600) == false)
    }

    @Test func playingOnceCompletesAfterTheFinalDuration() {
        let once = AnimationTimeline(
            playback: .once,
            steps: [.init(index: 5, durationMs: 100), .init(index: 6, durationMs: 100)]
        )

        #expect(once.hasCompleted(at: 0.19) == false)
        #expect(once.frame(at: 0.19) == 6)
        #expect(once.hasCompleted(at: 0.2))
    }

    @Test func reportsWhenTheNextFrameIsDue() {
        #expect(loop.timeUntilNextFrame(at: 0) == 0.2)
        #expect(loop.timeUntilNextFrame(at: 0.1) == 0.1)
        #expect(loop.timeUntilNextFrame(at: 0.2) == 0.3)
    }

    @Test func aHeldFinalFrameNeedsNoFurtherRedraw() {
        let resting = AnimationTimeline(playback: .hold, steps: [.init(index: 13, durationMs: 1000)])

        #expect(resting.timeUntilNextFrame(at: 2.0) == nil)
    }
}
