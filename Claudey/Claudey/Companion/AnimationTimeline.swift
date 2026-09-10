import CoreGraphics
import Foundation

struct AnimationTimeline: Sendable {
    let playback: AnimationPlayback
    let steps: [AnimationCatalog.Step]

    var duration: TimeInterval {
        steps.reduce(0) { $0 + TimeInterval($1.durationMs) / 1000 }
    }

    func frame(at elapsed: TimeInterval) -> Int {
        guard let last = steps.last else { return 0 }
        guard let position = position(at: elapsed) else { return last.id }
        return steps[position.step].id
    }

    func hasCompleted(at elapsed: TimeInterval) -> Bool {
        playback == .once && elapsed >= duration
    }

    func timeUntilNextFrame(at elapsed: TimeInterval) -> TimeInterval? {
        guard let position = position(at: elapsed) else { return nil }
        return position.endsIn
    }

    private func position(at elapsed: TimeInterval) -> (step: Int, endsIn: TimeInterval)? {
        guard !steps.isEmpty, duration > 0 else { return nil }

        var offset = max(elapsed, 0)
        if playback == .loop {
            offset = offset.truncatingRemainder(dividingBy: duration)
        } else if offset >= duration {
            return nil
        }

        var start: TimeInterval = 0
        for (index, step) in steps.enumerated() {
            let end = start + TimeInterval(step.durationMs) / 1000
            if offset < end {
                return (index, end - offset)
            }
            start = end
        }
        return (steps.count - 1, 0)
    }
}
