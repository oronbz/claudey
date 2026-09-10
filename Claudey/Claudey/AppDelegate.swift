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
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        do {
            let catalog = try AnimationCatalog.bundled()
            let companion = CompanionController(catalog: catalog, sheet: try SpriteSheet.bundled(catalog: catalog))
            #if DEBUG
            companion.onClick = { NSLog("Claudey was clicked") }
            #endif
            companion.show()
            menuBar = MenuBarController(companion: companion)
            self.companion = companion
        } catch {
            NSLog("Claudey could not load his sprites: \(error)")
            NSApp.terminate(nil)
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
