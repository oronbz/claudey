import Foundation

/// Shapes captured from a live Herdr 0.8.2 server (protocol 20) on 2026-09-11.
enum HerdrFixtures {
    static func agent(
        pane: String, workspace: String = "w1", tab: String = "w1:t1", terminal: String,
        agent: String = "claude", status: String, session: String?, seq: Int
    ) -> String {
        let sessionJSON = session.map {
            """
            {"agent":"\(agent)","kind":"id","source":"herdr:\(agent)","value":"\($0)"}
            """
        } ?? "null"
        return """
        {"agent":"\(agent)","agent_session":\(sessionJSON),"agent_status":"\(status)",
         "cwd":"/Users/me/project","focused":false,"foreground_cwd":"/Users/me/project",
         "pane_id":"\(pane)","revision":7,"state_change_seq":\(seq),"tab_id":"\(tab)",
         "terminal_id":"\(terminal)","terminal_title":"◑ Claude Code",
         "terminal_title_stripped":"Claude Code","workspace_id":"\(workspace)"}
        """
    }

    static func snapshotResponse(id: String = "claudey-1", agents: [String]) -> Data {
        Data("""
        {"id":"\(id)","result":{"snapshot":{"agents":[\(agents.joined(separator: ","))],
         "focused_pane_id":"w1:p1","focused_tab_id":"w1:t1","focused_workspace_id":"w1",
         "layouts":[],"panes":[],"protocol":20,"tabs":[],"version":"0.8.2","workspaces":[]},
         "type":"session_snapshot"}}
        """.utf8)
    }

    static func ack(id: String) -> Data {
        Data("{\"id\":\"\(id)\",\"result\":{\"type\":\"subscription_started\"}}".utf8)
    }

    static func error(id: String, code: String, message: String) -> Data {
        Data("{\"id\":\"\(id)\",\"error\":{\"code\":\"\(code)\",\"message\":\"\(message)\"}}".utf8)
    }

    static func statusChanged(pane: String, workspace: String = "w1", agent: String = "claude", status: String) -> Data {
        Data("""
        {"data":{"agent":"\(agent)","agent_status":"\(status)","pane_id":"\(pane)","workspace_id":"\(workspace)"},
         "event":"pane.agent_status_changed"}
        """.utf8)
    }

    static func agentDetected(pane: String, workspace: String = "w1", agent: String = "claude", released: Bool) -> Data {
        let tail = released ? ",\"final_status\":\"idle\",\"released\":true" : ""
        return Data("""
        {"data":{"agent":"\(agent)","pane_id":"\(pane)"\(tail),"type":"pane_agent_detected","workspace_id":"\(workspace)"},
         "event":"pane_agent_detected"}
        """.utf8)
    }

    static func paneClosed(pane: String, workspace: String = "w1") -> Data {
        Data("{\"data\":{\"pane_id\":\"\(pane)\",\"type\":\"pane_closed\",\"workspace_id\":\"\(workspace)\"},\"event\":\"pane_closed\"}".utf8)
    }

    static func paneExited(pane: String, workspace: String = "w1") -> Data {
        Data("{\"data\":{\"pane_id\":\"\(pane)\",\"type\":\"pane_exited\",\"workspace_id\":\"\(workspace)\"},\"event\":\"pane_exited\"}".utf8)
    }

    static func paneMoved(from previous: String, to pane: String) -> Data {
        Data("""
        {"data":{"pane":{"agent":"claude","agent_status":"working","focused":false,"pane_id":"\(pane)","revision":1,
         "tab_id":"w2:t1","terminal_id":"term_moved","workspace_id":"w2"},"previous_pane_id":"\(previous)",
         "previous_tab_id":"w1:t1","previous_workspace_id":"w1","type":"pane_moved"},"event":"pane_moved"}
        """.utf8)
    }

    static func paneUpdated(pane: String, status: String) -> Data {
        Data("""
        {"data":{"pane":{"agent":"claude","agent_status":"\(status)","focused":true,"pane_id":"\(pane)","revision":3,
         "tab_id":"w1:t1","terminal_id":"term_x","workspace_id":"w1"},"type":"pane_updated"},"event":"pane_updated"}
        """.utf8)
    }
}
