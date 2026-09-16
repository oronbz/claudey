import AppKit

final class CompanionMenuController: NSObject, NSMenuItemValidation {
    let menu = NSMenu()
    var onQuit: () -> Void = { NSApp.terminate(nil) }
    var onShowReaction: (CompanionAnimation) -> Void = { _ in }

    private let link: HerdrLink
    private let loginItem: LoginItemService
    private let connectionItem: NSMenuItem
    private let launchAtLoginItem: NSMenuItem

    init(link: HerdrLink, loginItem: LoginItemService) {
        self.link = link
        self.loginItem = loginItem
        connectionItem = NSMenuItem(title: "", action: #selector(toggleConnection), keyEquivalent: "")
        launchAtLoginItem = NSMenuItem(title: "", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        super.init()

        #if DEBUG
        menu.addItem(reactionsItem())
        menu.addItem(.separator())
        #endif

        connectionItem.target = self
        launchAtLoginItem.target = self
        menu.addItem(connectionItem)
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Claudey", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        refresh()
    }

    /// Validation runs each time the menu opens, which is when a login item
    /// toggled in System Settings has to be reflected.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        refresh()
        return true
    }

    @objc func toggleConnection() {
        if link.isEnabled { link.disconnect() } else { link.connect() }
        refresh()
    }

    @objc func toggleLaunchAtLogin() {
        do {
            if loginItem.isEnabled {
                try loginItem.unregister()
            } else {
                try loginItem.register()
                if loginItem.requiresApproval { loginItem.openApprovalSettings() }
            }
        } catch {
            NSLog("Claudey could not change launch at login: %@", String(describing: error))
        }
        refresh()
    }

    private func refresh() {
        connectionItem.title = link.isEnabled ? "Disconnect from Herdr" : "Connect to Herdr"
        launchAtLoginItem.title = loginItem.requiresApproval
            ? "Launch at Login (approve in System Settings)"
            : "Launch at Login"
        launchAtLoginItem.state = loginItem.isEnabled ? .on : .off
    }

    @objc private func quit() {
        onQuit()
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
        onShowReaction(animation)
    }
    #endif
}
