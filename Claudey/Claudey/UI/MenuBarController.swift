import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let visibilityItem = NSMenuItem(
        title: "Hide Claudey",
        action: #selector(MenuBarTarget.toggleVisibility),
        keyEquivalent: ""
    )
    private let target: MenuBarTarget

    init(companion: CompanionController) {
        target = MenuBarTarget(companion: companion)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "pawprint.fill",
            accessibilityDescription: "Claudey"
        )

        let menu = NSMenu()
        visibilityItem.target = target
        target.visibilityItem = visibilityItem
        menu.addItem(visibilityItem)

        #if DEBUG
        menu.addItem(.separator())
        menu.addItem(reactionsItem())
        #endif

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Claudey", action: #selector(MenuBarTarget.quit), keyEquivalent: "q")
        quit.target = target
        menu.addItem(quit)

        statusItem.menu = menu
    }

    #if DEBUG
    private func reactionsItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Reaction (development)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for animation in CompanionAnimation.allCases {
            let entry = NSMenuItem(
                title: animation.rawValue,
                action: #selector(MenuBarTarget.showReaction(_:)),
                keyEquivalent: ""
            )
            entry.representedObject = animation
            entry.target = target
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }
    #endif
}

private final class MenuBarTarget: NSObject {
    weak var visibilityItem: NSMenuItem?

    private let companion: CompanionController

    init(companion: CompanionController) {
        self.companion = companion
    }

    @objc func toggleVisibility() {
        if companion.isVisible {
            companion.hide()
        } else {
            companion.show()
        }
        visibilityItem?.title = companion.isVisible ? "Hide Claudey" : "Show Claudey"
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    @objc func showReaction(_ sender: NSMenuItem) {
        guard let animation = sender.representedObject as? CompanionAnimation else { return }
        companion.show(animation)
    }
}
