import Foundation
import Testing
@testable import Shepherd

struct HerdrLinkTests {
    private final class Harness {
        let transport = FakeHerdrTransport()
        let scheduler = ManualScheduler()
        let behavior: CompanionBehavior
        let director: CompanionDirector
        let defaults: UserDefaults
        let suite = "shepherd-link-\(UUID().uuidString)"
        var socketPath = "/tmp/herdr.sock"
        var connectRequested = false
        var requestsTaken = 0
        private(set) var link: HerdrLink!

        init() throws {
            behavior = CompanionBehavior(catalog: try AnimationCatalog.bundled(), startedAt: 0)
            director = CompanionDirector(behavior: behavior, startedAt: 0)
            defaults = UserDefaults(suiteName: suite)!
            link = makeLink()
        }

        deinit { defaults.removePersistentDomain(forName: suite) }

        func relaunch() { link = makeLink() }

        private func makeLink() -> HerdrLink {
            let connection = HerdrConnection(transport: transport, scheduler: scheduler) { [unowned self] in socketPath }
            connection.onEvent = { [unowned self] event in director.apply(event, at: scheduler.now) }
            return HerdrLink(
                connection: connection,
                preference: ConnectionPreferenceStore(defaults: defaults),
                takeConnectRequest: { [unowned self] in
                    requestsTaken += 1
                    defer { connectRequested = false }
                    return connectRequested
                }
            )
        }

        var animation: CompanionAnimation { behavior.presentation(at: scheduler.now).animation }

        func goLive(agents: [String]) throws {
            let lifecycle = try #require(transport.liveLifecycle)
            lifecycle.acknowledge()
            scheduler.advance(by: HerdrConnection.flushDelay)
            transport.answerSnapshot(with: agents)
        }
    }

    private let working = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "working", session: "sess-a", seq: 40)
    private let ready = HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "idle", session: "sess-a", seq: 41)

    @Test func watchesHerdrFromTheFirstLaunch() throws {
        let harness = try Harness()

        harness.link.activate()

        #expect(harness.link.isEnabled)
        try harness.goLive(agents: [working])
        #expect(harness.animation == .working)
    }

    @Test func disconnectingRestsAndOutlivesRetryAndStartupHooks() throws {
        let harness = try Harness()
        harness.link.activate()
        try harness.goLive(agents: [working])

        harness.link.disconnect()

        #expect(harness.animation == .resting)
        #expect(!harness.link.isEnabled)
        harness.scheduler.advance(by: 60)
        #expect(harness.transport.liveLifecycle == nil)

        harness.link.activate()
        #expect(harness.transport.liveLifecycle == nil)
        #expect(harness.animation == .resting)
    }

    @Test func thePluginsConnectActionReconnectsAndShowsCurrentActivityWithoutAHop() throws {
        let harness = try Harness()
        harness.link.activate()
        try harness.goLive(agents: [working])
        harness.link.disconnect()

        harness.connectRequested = true
        harness.link.activate()

        #expect(harness.link.isEnabled)
        try harness.goLive(agents: [ready])
        #expect(harness.animation == .idle)
        #expect(harness.animation != .finished)
    }

    @Test func connectingFromTheMenuRestoresCurrentActivity() throws {
        let harness = try Harness()
        harness.link.activate()
        try harness.goLive(agents: [ready])
        harness.link.disconnect()

        harness.link.connect()

        #expect(harness.link.isEnabled)
        try harness.goLive(agents: [working])
        #expect(harness.animation == .working)
    }

    @Test func aDisconnectIsRememberedAcrossRelaunch() throws {
        let harness = try Harness()
        harness.link.activate()
        try harness.goLive(agents: [working])
        harness.link.disconnect()

        harness.relaunch()
        harness.link.activate()

        #expect(!harness.link.isEnabled)
        #expect(harness.transport.liveLifecycle == nil)
    }

    @Test func aConnectRequestAtLaunchOverridesARememberedDisconnect() throws {
        let harness = try Harness()
        harness.link.activate()
        harness.link.disconnect()

        harness.relaunch()
        harness.connectRequested = true
        harness.link.activate()

        #expect(harness.link.isEnabled)
        #expect(harness.transport.liveLifecycle != nil)
    }

    @Test func reopeningWhileConnectedFollowsTheSocketThePluginNames() throws {
        let harness = try Harness()
        harness.link.activate()
        try harness.goLive(agents: [working])

        harness.socketPath = "/tmp/named/herdr.sock"
        harness.link.activate()

        #expect(harness.transport.liveLifecycle?.socketPath == "/tmp/named/herdr.sock")
        #expect(harness.animation == .resting)
    }

    @Test func connectingTwiceOpensOneConnection() throws {
        let harness = try Harness()
        harness.link.activate()
        try harness.goLive(agents: [working])
        let subscriptions = harness.transport.subscriptions.count

        harness.link.connect()
        harness.link.activate()

        #expect(harness.transport.subscriptions.count == subscriptions)
        #expect(harness.animation == .working)
    }
}
