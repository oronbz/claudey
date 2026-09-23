import Foundation

final class HerdrNavigationHost: NavigationHost {
    private let herdr: HerdrConnection
    private let ghostty: GhosttyHost

    init(herdr: HerdrConnection, ghostty: GhosttyHost) {
        self.herdr = herdr
        self.ghostty = ghostty
    }

    func focusPane(_ paneID: String, completion: @escaping (Bool) -> Void) {
        herdr.focusPane(paneID, completion: completion)
    }

    func activateTerminal(completion: @escaping (Bool) -> Void) {
        ghostty.activateHerdrTerminal(completion: completion)
    }
}
