import Foundation

final class CompanionDirector {
    private let model = ActivityModel()
    private let behavior: CompanionBehavior
    private var shown: CompanionAnimation

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
        if !update.finished.isEmpty, update.state != .needsYou {
            behavior.show(.finished, at: now)
        }
    }
}
