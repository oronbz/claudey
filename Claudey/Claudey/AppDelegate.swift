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
    private var companion: CompanionController?
    private var menu: CompanionMenuController?
    private var herdr: HerdrConnection?
    #if DEBUG
    private var clickSignal: DispatchSourceSignal?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard Self.isRunningTests || Self.isTheOnlyInstance else {
            NSLog("Claudey is already running; leaving the existing companion in place")
            NSApp.terminate(nil)
            return
        }

        do {
            let catalog = try AnimationCatalog.bundled()
            let companion = CompanionController(catalog: catalog, sheet: try SpriteSheet.bundled(catalog: catalog))
            let menu = CompanionMenuController(companion: companion)
            companion.attach(menu.menu)
            companion.show()
            self.menu = menu
            self.companion = companion

            guard !Self.isRunningTests else { return }
            let herdr = HerdrConnection(transport: HerdrSocketTransport(), scheduler: TimerScheduler()) {
                HerdrConnectionContext.resolve().socketPath
            }
            herdr.onEvent = { [weak companion] event in
                #if DEBUG
                NSLog("Claudey activity: \(event)")
                #endif
                companion?.apply(event)
            }
            companion.navigate(through: HerdrNavigationHost(herdr: herdr, ghostty: GhosttyHost()))
            #if DEBUG
            listenForScriptedClicks()
            #endif
            herdr.start()
            self.herdr = herdr
        } catch {
            NSLog("Claudey could not load his sprites: \(error)")
            NSApp.terminate(nil)
        }
    }

    /// The plugin's launcher reopens the running app after rewriting the
    /// connection context, so a reopen is the cue to re-read it.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        herdr?.refresh()
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    #if DEBUG
    /// `kill -USR1 $(pgrep -x Claudey)` clicks him from a script.
    private func listenForScriptedClicks() {
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            self?.companion?.click()
        }
        source.resume()
        clickSignal = source
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
