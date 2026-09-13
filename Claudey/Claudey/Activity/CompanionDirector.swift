import Foundation

final class CompanionDirector {
    private let model = ActivityModel()
    private let behavior: CompanionBehavior
    private var shown: CompanionAnimation
    private var celebrating: SessionIdentity?

    init(behavior: CompanionBehavior, startedAt now: TimeInterval) {
        self.behavior = behavior
        shown = model.state
        behavior.show(shown, at: now)
    }

    var sessions: [SessionRecord] { model.sessions }

    func apply(_ event: ActivityEvent, at now: TimeInterval) {
        let update = model.apply(event)

        if update.state != shown {
            behavior.show(update.state, at: now)
            shown = update.state
        }
        if let finished = update.finished.last, update.state != .needsYou {
            behavior.show(.finished, at: now)
            celebrating = finished
        }
    }

    /// Resolved at click time against the sessions Herdr currently reports, so
    /// a hop whose session has since closed or changed occupant targets nothing
    /// rather than whichever session happens to remain.
    func clickTarget(at now: TimeInterval) -> SessionIdentity? {
        let hopping = behavior.isPlaying(.finished, at: now)
        return model.navigationTarget(celebrating: hopping ? celebrating : nil)
    }

    func reactPlayfully(at now: TimeInterval) {
        behavior.reactPlayfully(at: now)
    }
}
