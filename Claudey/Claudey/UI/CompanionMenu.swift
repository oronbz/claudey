import AppKit

final class CompanionMenuController: NSObject {
    let menu = NSMenu()

    private let companion: CompanionController

    init(companion: CompanionController) {
        self.companion = companion
        super.init()

        #if DEBUG
        menu.addItem(reactionsItem())
        menu.addItem(.separator())
        #endif

        let quit = NSMenuItem(title: "Quit Claudey", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    #if DEBUG
    private func reactionsItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Reaction (development)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for animation in CompanionAnimation.allCases {
            let entry = NSMenuItem(title: animation.rawValue, action: #selector(showReaction(_:)), keyEquivalent: "")
            entry.representedObject = animation
            entry.target = self
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    @objc private func showReaction(_ sender: NSMenuItem) {
        guard let animation = sender.representedObject as? CompanionAnimation else { return }
        companion.show(animation)
    }
    #endif
}
