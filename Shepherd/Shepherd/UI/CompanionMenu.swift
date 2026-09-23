import AppKit

final class CompanionMenuController: NSObject, NSMenuItemValidation {
    let menu = NSMenu()
    var onQuit: () -> Void = { NSApp.terminate(nil) }
    var onShowReaction: (CompanionAnimation) -> Void = { _ in }
    var onChooseAvatar: (Avatar) -> Void = { _ in }

    private let link: HerdrLink
    private let avatars: AvatarPreferenceStore
    private let connectionItem: NSMenuItem
    private let avatarItems: [NSMenuItem]

    init(link: HerdrLink, avatars: AvatarPreferenceStore, avatarNames: [(Avatar, String)]) {
        self.link = link
        self.avatars = avatars
        connectionItem = NSMenuItem(title: "", action: #selector(toggleConnection), keyEquivalent: "")
        avatarItems = avatarNames.map { avatar, name in
            let item = NSMenuItem(title: name, action: #selector(chooseAvatar(_:)), keyEquivalent: "")
            item.representedObject = avatar.rawValue
            return item
        }
        super.init()

        #if DEBUG
        menu.addItem(reactionsItem())
        menu.addItem(.separator())
        #endif

        let avatarMenu = NSMenu()
        for item in avatarItems {
            item.target = self
            avatarMenu.addItem(item)
        }
        let avatarItem = NSMenuItem(title: "Avatar", action: nil, keyEquivalent: "")
        avatarItem.submenu = avatarMenu
        menu.addItem(avatarItem)
        menu.addItem(.separator())

        connectionItem.target = self
        menu.addItem(connectionItem)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Shepherd", action: #selector(quit), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)

        refresh()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        refresh()
        return true
    }

    @objc func toggleConnection() {
        if link.isEnabled { link.disconnect() } else { link.connect() }
        refresh()
    }

    @objc func chooseAvatar(_ sender: NSMenuItem) {
        guard let avatar = (sender.representedObject as? String).flatMap(Avatar.init(rawValue:)) else { return }
        avatars.avatar = avatar
        onChooseAvatar(avatar)
        refresh()
    }

    private func refresh() {
        for item in avatarItems {
            item.state = item.representedObject as? String == avatars.avatar.rawValue ? .on : .off
        }
        connectionItem.title = link.isEnabled ? "Disconnect from Herdr" : "Connect to Herdr"
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
