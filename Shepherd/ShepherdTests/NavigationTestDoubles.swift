import Foundation
@testable import Shepherd

final class FakeNavigationHost: NavigationHost {
    var paneExists: (String) -> Bool = { _ in true }
    var terminalReachable = true
    var answersImmediately = true

    private(set) var focusedPanes: [String] = []
    private(set) var terminalActivations = 0
    private var pending: [() -> Void] = []

    func focusPane(_ paneID: String, completion: @escaping (Bool) -> Void) {
        focusedPanes.append(paneID)
        let answer = { completion(self.paneExists(paneID)) }
        answersImmediately ? answer() : pending.append(answer)
    }

    func answerPending() {
        let answers = pending
        pending = []
        answers.forEach { $0() }
    }

    func activateTerminal(completion: @escaping (Bool) -> Void) {
        terminalActivations += 1
        completion(terminalReachable)
    }
}
