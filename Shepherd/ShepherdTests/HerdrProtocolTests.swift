import Foundation
import Testing
@testable import Shepherd

struct HerdrProtocolTests {
    @Test func aSnapshotBecomesSessionRecords() throws {
        let data = HerdrFixtures.snapshotResponse(agents: [
            HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "working", session: "sess-a", seq: 40),
            HerdrFixtures.agent(pane: "w1:p2", terminal: "term_b", agent: "codex", status: "blocked", session: nil, seq: 41),
            HerdrFixtures.agent(pane: "w1:p3", terminal: "term_c", status: "done", session: "sess-c", seq: 12),
            HerdrFixtures.agent(pane: "w1:p4", terminal: "term_d", status: "unknown", session: nil, seq: 2),
        ])

        let response = try JSONDecoder().decode(HerdrResponse<HerdrSnapshotResult>.self, from: data)
        let sessions = try #require(response.result?.snapshot.sessions)

        #expect(sessions.map(\.status) == [.working, .needsYou, .ready, .uncertain])
        #expect(sessions[0].identity == SessionIdentity(
            paneID: "w1:p1", terminalID: "term_a", workspaceID: "w1", tabID: "w1:t1",
            agent: "claude", agentSession: "sess-a"
        ))
        #expect(sessions[1].identity.agentSession == nil)
    }

    @Test func aPaneWithoutAnAgentIsNotASession() throws {
        let agentless = """
        {"agent":null,"agent_status":"unknown","focused":false,"pane_id":"w1:p9","revision":0,
         "tab_id":"w1:t1","terminal_id":"term_z","workspace_id":"w1"}
        """
        let data = HerdrFixtures.snapshotResponse(agents: [agentless])

        let response = try JSONDecoder().decode(HerdrResponse<HerdrSnapshotResult>.self, from: data)

        #expect(response.result?.snapshot.sessions.isEmpty == true)
    }

    @Test func pushedEventsAreRecognised() {
        #expect(HerdrEvent(line: HerdrFixtures.statusChanged(pane: "w1:p1", status: "blocked"))
            == .agentStatusChanged(paneID: "w1:p1", agent: "claude", status: .blocked))
        let lifecycleForm = Data("""
        {"data":{"agent":"claude","agent_status":"done","pane_id":"w1:p1","type":"pane_agent_status_changed",
         "workspace_id":"w1"},"event":"pane_agent_status_changed"}
        """.utf8)
        #expect(HerdrEvent(line: lifecycleForm) == .agentStatusChanged(paneID: "w1:p1", agent: "claude", status: .done))
        #expect(HerdrEvent(line: HerdrFixtures.agentDetected(pane: "w1:p1", released: true))
            == .agentDetected(paneID: "w1:p1", agent: "claude", released: true))
        #expect(HerdrEvent(line: HerdrFixtures.agentDetected(pane: "w1:p1", released: false))
            == .agentDetected(paneID: "w1:p1", agent: "claude", released: false))
        #expect(HerdrEvent(line: HerdrFixtures.paneClosed(pane: "w1:p1")) == .paneRemoved(paneID: "w1:p1"))
        #expect(HerdrEvent(line: HerdrFixtures.paneExited(pane: "w1:p1")) == .paneRemoved(paneID: "w1:p1"))
        #expect(HerdrEvent(line: HerdrFixtures.paneMoved(from: "w1:p1", to: "w2:p1"))
            == .paneMoved(previousPaneID: "w1:p1", paneID: "w2:p1"))
        #expect(HerdrEvent(line: HerdrFixtures.paneUpdated(pane: "w1:p1", status: "idle")) == .other("pane_updated"))
    }

    @Test func acknowledgementsAndErrorsAreNotEvents() {
        #expect(HerdrEvent(line: HerdrFixtures.ack(id: "x")) == nil)
        #expect(HerdrEvent(line: HerdrFixtures.error(id: "x", code: "pane_not_found", message: "gone")) == nil)
        #expect(HerdrEvent(line: Data("not json".utf8)) == nil)
    }

    @Test func requestsAreSingleNewlineTerminatedJSONLines() throws {
        let line = HerdrRequest.subscribe([.paneClosed, .agentStatus(paneID: "w1:p1")]).line(id: "r1")

        #expect(line.last == 0x0A)
        let body = try #require(JSONSerialization.jsonObject(with: line) as? [String: Any])
        #expect(body["id"] as? String == "r1")
        #expect(body["method"] as? String == "events.subscribe")
        let subscriptions = try #require((body["params"] as? [String: Any])?["subscriptions"] as? [[String: String]])
        #expect(subscriptions == [["type": "pane.closed"], ["type": "pane.agent_status_changed", "pane_id": "w1:p1"]])

        let snapshot = try #require(JSONSerialization.jsonObject(with: HerdrRequest.snapshot.line(id: "r2")) as? [String: Any])
        #expect(snapshot["method"] as? String == "session.snapshot")
        #expect((snapshot["params"] as? [String: Any])?.isEmpty == true)
    }

    @Test func aStatusHerdrAddsLaterIsUncertainRatherThanFatal() throws {
        let data = HerdrFixtures.snapshotResponse(agents: [
            HerdrFixtures.agent(pane: "w1:p1", terminal: "term_a", status: "paused", session: nil, seq: 1),
        ])

        let response = try JSONDecoder().decode(HerdrResponse<HerdrSnapshotResult>.self, from: data)

        #expect(response.result?.snapshot.sessions.map(\.status) == [.uncertain])
    }

    @Test func herdrStatusesTranslateToSessionStatuses() {
        #expect(HerdrAgentStatus.working.sessionStatus == .working)
        #expect(HerdrAgentStatus.blocked.sessionStatus == .needsYou)
        #expect(HerdrAgentStatus.idle.sessionStatus == .ready)
        #expect(HerdrAgentStatus.done.sessionStatus == .ready)
        #expect(HerdrAgentStatus.unknown.sessionStatus == .uncertain)
    }
}
