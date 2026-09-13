import Foundation

/// Herdr's inner pane focus and the host terminal's activation are separate
/// operations with separate failure modes, so they are requested separately.
protocol NavigationHost: AnyObject {
    func focusPane(_ paneID: String, completion: @escaping (Bool) -> Void)
    func activateTerminal(completion: @escaping (Bool) -> Void)
}

enum NavigationOutcome: Equatable {
    case focusedPane(String)
    case activatedHost
    case unavailable
}

final class ClickNavigator {
    var onOutcome: ((NavigationOutcome) -> Void)?

    private let director: CompanionDirector
    private let host: NavigationHost
    private var navigating = false

    init(director: CompanionDirector, host: NavigationHost) {
        self.director = director
        self.host = host
    }

    func click(at now: TimeInterval) {
        guard !navigating else { return }
        navigating = true
        guard let target = director.clickTarget(at: now) else { return activateHost(at: now) }

        host.focusPane(target.paneID) { [weak self] focused in
            guard let self else { return }
            guard focused else { return activateHost(at: now) }
            host.activateTerminal { [weak self] _ in
                self?.finish(.focusedPane(target.paneID))
            }
        }
    }

    private func activateHost(at now: TimeInterval) {
        host.activateTerminal { [weak self] activated in
            guard let self else { return }
            if !activated { director.reactPlayfully(at: now) }
            finish(activated ? .activatedHost : .unavailable)
        }
    }

    private func finish(_ outcome: NavigationOutcome) {
        navigating = false
        onOutcome?(outcome)
    }
}
