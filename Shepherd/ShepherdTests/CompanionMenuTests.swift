import AppKit
import Testing
@testable import Shepherd

@MainActor
@Suite(.serialized)
struct CompanionMenuTests {
    private final class Harness {
        let transport = FakeHerdrTransport()
        let scheduler = ManualScheduler()
        let behavior: CompanionBehavior
        let director: CompanionDirector
        let defaults: UserDefaults
        let suite = "shepherd-menu-\(UUID().uuidString)"
        let link: HerdrLink
        let menu: CompanionMenuController
        let avatars: AvatarPreferenceStore
        var quits = 0
        var chosenAvatars: [Avatar] = []

        init() throws {
            behavior = CompanionBehavior(catalog: try AnimationCatalog.bundled(), startedAt: 0)
            director = CompanionDirector(behavior: behavior, startedAt: 0)
            defaults = UserDefaults(suiteName: suite)!
            let connection = HerdrConnection(transport: transport, scheduler: scheduler) { "/tmp/herdr.sock" }
            link = HerdrLink(connection: connection, preference: ConnectionPreferenceStore(defaults: defaults)) { false }
            avatars = AvatarPreferenceStore(defaults: defaults)
            menu = CompanionMenuController(
                link: link,
                avatars: avatars,
                avatarNames: try Avatar.allCases.map { ($0, try AnimationCatalog.bundled($0).name) }
            )
            menu.onChooseAvatar = { [unowned self] in chosenAvatars.append($0) }
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

        func avatarItems() throws -> [NSMenuItem] {
            let submenu = try #require(try item("Avatar").submenu)
            submenu.update()
            return submenu.items
        }

        func chooseAvatar(_ name: String) throws {
            let submenu = try #require(try item("Avatar").submenu)
            let item = try #require(submenu.items.first { $0.title == name })
            submenu.performActionForItem(at: submenu.index(of: item))
        }

        func goLive(agents: [String]) throws {
            let lifecycle = try #require(transport.liveLifecycle)
            lifecycle.acknowledge()
            scheduler.advance(by: HerdrConnection.flushDelay)
            transport.answerSnapshot(with: agents)
        }
    }

    private let working = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "working", session: "sess-a", seq: 40)

    @Test func offersOnlyAvatarConnectionAndQuit() throws {
        let harness = try Harness()

        let titles = harness.titles.filter { !$0.contains("development") }

        #expect(titles == ["Avatar", "Disconnect from Herdr", "Quit Shepherd"])
    }

    @Test func theAvatarMenuListsEveryAvatarAndChecksBlockByDefault() throws {
        let harness = try Harness()

        let items = try harness.avatarItems()

        #expect(items.map(\.title) == ["Block", "Soft Spark", "Ram", "Catpuccino"])
        #expect(items.map(\.state) == [.on, .off, .off, .off])
    }

    @Test func choosingAnAvatarSwapsHimAndIsRemembered() throws {
        let harness = try Harness()

        try harness.chooseAvatar("Soft Spark")

        #expect(harness.chosenAvatars == [.softSpark])
        #expect(try harness.avatarItems().map(\.state) == [.off, .on, .off, .off])
        #expect(AvatarPreferenceStore(defaults: harness.defaults).avatar == .softSpark)
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

    @Test func quitAsksTheAppToQuitOnce() throws {
        let harness = try Harness()

        try harness.choose("Quit")

        #expect(harness.quits == 1)
    }
}
