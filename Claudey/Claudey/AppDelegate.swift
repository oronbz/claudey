import Cocoa

@main
struct ClaudeyApp {
    /// NSApplication holds its delegate weakly, so the app owns it here.
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `tools/uninstall.sh` launches the app once with this argument so the
    /// login item is removed by the only party allowed to remove it.
    static let disableLaunchAtLoginArgument = "--disable-launch-at-login"

    private let loginItem = MainAppLoginItem()
    private let avatars = AvatarPreferenceStore()
    private var companion: CompanionController?
    private var menu: CompanionMenuController?
    private var link: HerdrLink?
    #if DEBUG
    private var scriptedSignals: [DispatchSourceSignal] = []
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if CommandLine.arguments.contains(Self.disableLaunchAtLoginArgument) {
            return disableLaunchAtLoginAndQuit()
        }

        guard Self.isRunningTests || Self.isTheOnlyInstance else {
            NSLog("Claudey is already running; leaving the existing companion in place")
            NSApp.terminate(nil)
            return
        }

        do {
            let library = try CompanionAvatar.bundledLibrary()
            guard let current = library[avatars.avatar] else {
                throw AnimationCatalog.Failure.missingResource(avatars.avatar.rawValue)
            }
            let companion = CompanionController(avatar: current)
            self.companion = companion

            guard !Self.isRunningTests else { return companion.show() }
            let herdr = HerdrConnection(transport: HerdrSocketTransport(), scheduler: TimerScheduler()) {
                HerdrConnectionContext.resolve().socketPath
            }
            herdr.onEvent = { [weak companion] event in
                #if DEBUG
                NSLog("Claudey activity: \(event)")
                #endif
                companion?.apply(event)
            }
            let link = HerdrLink(connection: herdr)
            let menu = CompanionMenuController(
                link: link,
                loginItem: loginItem,
                avatars: avatars,
                avatarNames: Avatar.allCases.compactMap { avatar in library[avatar].map { (avatar, $0.name) } }
            )
            menu.onShowReaction = { [weak companion] in companion?.show($0) }
            menu.onChooseAvatar = { [weak companion] in library[$0].map { companion?.use($0) } }
            companion.attach(menu.menu)
            companion.navigate(through: HerdrNavigationHost(herdr: herdr, ghostty: GhosttyHost()))
            companion.show()
            #if DEBUG
            listenForScriptedControls()
            #endif
            link.activate()
            self.menu = menu
            self.link = link
        } catch {
            NSLog("Claudey could not load his sprites: \(error)")
            NSApp.terminate(nil)
        }
    }

    /// The plugin's launcher reopens the running app after rewriting the
    /// connection context, so a reopen is the cue to re-read it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        link?.activate()
        return false
    }

    private func disableLaunchAtLoginAndQuit() {
        if loginItem.isEnabled || loginItem.requiresApproval {
            do {
                try loginItem.unregister()
                NSLog("Claudey launch at login disabled")
            } catch {
                NSLog("Claudey could not disable launch at login: %@", String(describing: error))
            }
        } else {
            NSLog("Claudey launch at login was already off")
        }
        NSApp.terminate(nil)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    #if DEBUG
    /// From a script, `kill -USR1 $(pgrep -x Claudey)` clicks him, `-USR2`
    /// chooses his connect/disconnect menu item and `-INFO` toggles launch at
    /// login, so the menu's effects can be driven without a pointer.
    private func listenForScriptedControls() {
        listen(to: SIGUSR1) { $0.companion?.click() }
        listen(to: SIGUSR2) { $0.menu?.toggleConnection() }
        listen(to: SIGINFO) { $0.menu?.toggleLaunchAtLogin() }
    }

    private func listen(to signalNumber: Int32, _ handler: @escaping (AppDelegate) -> Void) {
        signal(signalNumber, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            handler(self)
        }
        source.resume()
        scriptedSignals.append(source)
    }
    #endif

    /// The test host must neither yield to a developer's running copy nor
    /// talk to the real Herdr socket.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
    }

    private static var isTheOnlyInstance: Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return true }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .allSatisfy { $0.processIdentifier == ProcessInfo.processInfo.processIdentifier }
    }
}
