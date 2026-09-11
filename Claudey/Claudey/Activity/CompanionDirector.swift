import Foundation

/// Turns session activity into what Claudey shows. A completion hop is only
/// acknowledged when nothing more important is on screen.
final class CompanionDirector {
    private let model = ActivityModel()
    private let behavior: CompanionBehavior
    private var shown: CompanionAnimation?

    init(behavior: CompanionBehavior) {
        self.behavior = behavior
    }

    var sessions: [SessionRecord] { model.sessions }

    func apply(_ event: ActivityEvent, at now: TimeInterval) {
        let update = model.apply(event)

        if update.state != shown {
            behavior.show(update.state, at: now)
            shown = update.state
        }
        if !update.finished.isEmpty, update.state != .needsYou {
            behavior.show(.finished, at: now)
        }
    }
}
