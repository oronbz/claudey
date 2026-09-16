import AppKit
import Testing
@testable import Claudey

@MainActor
@Suite(.serialized)
struct CompanionMenuTests {
    private final class FakeLoginItem: LoginItemService {
        var isEnabled = false
        var requiresApproval = false
        var approvalRequestedOnNextRegister = false
        var settingsOpened = 0
        var failure: Error?

        func register() throws {
            if let failure { throw failure }
            if approvalRequestedOnNextRegister {
                requiresApproval = true
            } else {
                isEnabled = true
            }
        }

        func unregister() throws {
            if let failure { throw failure }
            isEnabled = false
            requiresApproval = false
        }

        func openApprovalSettings() { settingsOpened += 1 }
    }

    private final class Harness {
        let transport = FakeHerdrTransport()
        let scheduler = ManualScheduler()
        let behavior: CompanionBehavior
        let director: CompanionDirector
        let loginItem = FakeLoginItem()
        let defaults: UserDefaults
        let suite = "claudey-menu-\(UUID().uuidString)"
        let link: HerdrLink
        let menu: CompanionMenuController
        var quits = 0

        init() throws {
            behavior = CompanionBehavior(catalog: try AnimationCatalog.bundled(), startedAt: 0)
            director = CompanionDirector(behavior: behavior, startedAt: 0)
            defaults = UserDefaults(suiteName: suite)!
            let connection = HerdrConnection(transport: transport, scheduler: scheduler) { "/tmp/herdr.sock" }
            link = HerdrLink(connection: connection, preference: ConnectionPreferenceStore(defaults: defaults)) { false }
            menu = CompanionMenuController(link: link, loginItem: loginItem)
            connection.onEvent = { [unowned self] event in director.apply(event, at: scheduler.now) }
            menu.onQuit = { [unowned self] in quits += 1 }
            link.activate()
        }

        deinit { defaults.removePersistentDomain(forName: suite) }

        var animation: CompanionAnimation { behavior.presentation(at: scheduler.now).animation }

        var titles: [String] {
            menu.menu.update()
            return menu.menu.items.filter { !$0.isSeparatorItem }.map(\.title)
        }

        func item(_ prefix: String) throws -> NSMenuItem {
            menu.menu.update()
            return try #require(menu.menu.items.first { $0.title.hasPrefix(prefix) })
        }

        func choose(_ prefix: String) throws {
            let item = try self.item(prefix)
            menu.menu.performActionForItem(at: menu.menu.index(of: item))
        }

        func goLive(agents: [String]) throws {
            let lifecycle = try #require(transport.liveLifecycle)
            lifecycle.acknowledge()
            scheduler.advance(by: HerdrConnection.flushDelay)
            transport.answerSnapshot(with: agents)
        }
    }

    private let working = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "working", session: "sess-a", seq: 40)

    @Test func offersOnlyConnectionLaunchAtLoginAndQuit() throws {
        let harness = try Harness()

        let titles = harness.titles.filter { !$0.contains("development") }

        #expect(titles == ["Disconnect from Herdr", "Launch at Login", "Quit Claudey"])
    }

    @Test func disconnectAndConnectSwapPlaces() throws {
        let harness = try Harness()
        try harness.goLive(agents: [working])

        try harness.choose("Disconnect")
        #expect(harness.animation == .resting)
        #expect(harness.titles.contains("Connect to Herdr"))
        #expect(!harness.titles.contains("Disconnect from Herdr"))

        try harness.choose("Connect")
        try harness.goLive(agents: [working])
        #expect(harness.animation == .working)
        #expect(harness.titles.contains("Disconnect from Herdr"))
    }

    @Test func launchAtLoginStartsOffAndToggles() throws {
        let harness = try Harness()
        #expect(try harness.item("Launch at Login").state == .off)

        try harness.choose("Launch at Login")
        #expect(harness.loginItem.isEnabled)
        #expect(try harness.item("Launch at Login").state == .on)

        try harness.choose("Launch at Login")
        #expect(!harness.loginItem.isEnabled)
        #expect(try harness.item("Launch at Login").state == .off)
    }

    @Test func launchAtLoginReflectsChangesMadeInSystemSettings() throws {
        let harness = try Harness()

        harness.loginItem.isEnabled = true

        #expect(try harness.item("Launch at Login").state == .on)
    }

    @Test func aLoginItemAwaitingApprovalOpensSystemSettingsAndStaysOff() throws {
        let harness = try Harness()
        harness.loginItem.approvalRequestedOnNextRegister = true

        try harness.choose("Launch at Login")

        #expect(harness.loginItem.settingsOpened == 1)
        #expect(try harness.item("Launch at Login").state == .off)
        #expect(try harness.item("Launch at Login").title == "Launch at Login (approve in System Settings)")
    }

    @Test func aRefusedLoginItemChangeLeavesTheMenuHonest() throws {
        let harness = try Harness()
        harness.loginItem.failure = CocoaError(.fileWriteNoPermission)

        try harness.choose("Launch at Login")

        #expect(!harness.loginItem.isEnabled)
        #expect(try harness.item("Launch at Login").state == .off)
    }

    @Test func quitAsksTheAppToQuitOnce() throws {
        let harness = try Harness()

        try harness.choose("Quit")

        #expect(harness.quits == 1)
    }
}
