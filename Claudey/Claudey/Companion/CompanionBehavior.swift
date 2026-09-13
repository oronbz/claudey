import CoreGraphics
import Foundation

struct CompanionPresentation: Equatable {
    let animation: CompanionAnimation
    let frameID: Int
}

/// Time is supplied by the caller so the reaction Claudey shows is observable
/// without waiting on a clock.
final class CompanionBehavior {
    private struct Playing {
        let animation: CompanionAnimation
        let timeline: AnimationTimeline
        var startedAt: TimeInterval
    }

    private let catalog: AnimationCatalog
    private var base: Playing
    private var transient: Playing?
    private var hovering: Playing?

    init(catalog: AnimationCatalog, startedAt: TimeInterval) {
        self.catalog = catalog
        self.base = Playing(
            animation: .idle,
            timeline: catalog.timeline(for: .idle) ?? AnimationTimeline(playback: .hold, steps: []),
            startedAt: startedAt
        )
    }

    func show(_ animation: CompanionAnimation, at now: TimeInterval) {
        guard let timeline = catalog.timeline(for: animation) else { return }
        let playing = Playing(animation: animation, timeline: timeline, startedAt: now)

        if timeline.playback == .once {
            transient = playing
        } else {
            base = playing
            transient = nil
        }
    }

    func reactPlayfully(at now: TimeInterval) {
        guard let hover = catalog.timeline(for: .hover) else { return }
        let once = AnimationTimeline(playback: .once, steps: hover.steps)
        transient = Playing(animation: .hover, timeline: once, startedAt: now)
        hovering?.startedAt = now
    }

    /// Ignores the hover reaction, which is what a click usually arrives through.
    func isPlaying(_ animation: CompanionAnimation, at now: TimeInterval) -> Bool {
        if let transient, !transient.timeline.hasCompleted(at: now - transient.startedAt) {
            return transient.animation == animation
        }
        return base.animation == animation
    }

    func setHovering(_ isHovering: Bool, at now: TimeInterval) {
        guard isHovering else {
            hovering = nil
            base.startedAt = now
            return
        }
        guard let timeline = catalog.timeline(for: .hover) else { return }
        hovering = Playing(animation: .hover, timeline: timeline, startedAt: now)
    }

    func presentation(at now: TimeInterval) -> CompanionPresentation {
        let playing = current(at: now)
        return CompanionPresentation(
            animation: playing.animation,
            frameID: playing.timeline.frame(at: now - playing.startedAt)
        )
    }

    func timeUntilNextFrame(at now: TimeInterval) -> TimeInterval? {
        let playing = current(at: now)
        return playing.timeline.timeUntilNextFrame(at: now - playing.startedAt)
    }

    private func current(at now: TimeInterval) -> Playing {
        if let hovering { return hovering }
        if let transient, !transient.timeline.hasCompleted(at: now - transient.startedAt) {
            return transient
        }
        return base
    }
}
