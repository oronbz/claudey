import Foundation

enum HerdrAgentStatus: String, Decodable, Sendable {
    case idle
    case working
    case blocked
    case done
    case unknown

    var sessionStatus: SessionStatus {
        switch self {
        case .working: .working
        case .blocked: .needsYou
        case .idle, .done: .ready
        case .unknown: .uncertain
        }
    }
}

struct HerdrAgentRecord: Decodable, Equatable, Sendable {
    struct Session: Decodable, Equatable, Sendable {
        let value: String
    }

    let paneID: String
    let terminalID: String
    let workspaceID: String
    let tabID: String
    let agent: String?
    let agentStatus: HerdrAgentStatus
    let agentSession: Session?
    let stateChangeSeq: UInt64?

    private enum CodingKeys: String, CodingKey {
        case paneID = "pane_id"
        case terminalID = "terminal_id"
        case workspaceID = "workspace_id"
        case tabID = "tab_id"
        case agent
        case agentStatus = "agent_status"
        case agentSession = "agent_session"
        case stateChangeSeq = "state_change_seq"
    }

    var sessionRecord: SessionRecord? {
        guard let agent else { return nil }
        return SessionRecord(
            identity: SessionIdentity(
                paneID: paneID,
                terminalID: terminalID,
                workspaceID: workspaceID,
                tabID: tabID,
                agent: agent,
                agentSession: agentSession?.value
            ),
            status: agentStatus.sessionStatus,
            changeOrder: stateChangeSeq ?? 0
        )
    }
}

struct HerdrSnapshot: Decodable, Sendable {
    let version: String
    let protocolVersion: UInt32
    let agents: [HerdrAgentRecord]

    private enum CodingKeys: String, CodingKey {
        case version
        case protocolVersion = "protocol"
        case agents
    }

    var sessions: [SessionRecord] {
        agents.compactMap(\.sessionRecord)
    }
}

struct HerdrError: Decodable, Error, Equatable, Sendable {
    let code: String
    let message: String
}

struct HerdrResponse<Body: Decodable>: Decodable {
    let id: String
    let result: Body?
    let error: HerdrError?
}

struct HerdrSnapshotResult: Decodable, Sendable {
    let snapshot: HerdrSnapshot
}

struct HerdrAcknowledgement: Decodable, Sendable {
    let type: String
}

enum HerdrSubscription: Equatable, Sendable {
    case paneClosed
    case paneExited
    case paneMoved
    case paneAgentDetected
    case agentStatus(paneID: String)

    var json: [String: String] {
        switch self {
        case .paneClosed: ["type": "pane.closed"]
        case .paneExited: ["type": "pane.exited"]
        case .paneMoved: ["type": "pane.moved"]
        case .paneAgentDetected: ["type": "pane.agent_detected"]
        case .agentStatus(let paneID): ["type": "pane.agent_status_changed", "pane_id": paneID]
        }
    }
}

enum HerdrRequest {
    case snapshot
    case subscribe([HerdrSubscription])

    var method: String {
        switch self {
        case .snapshot: "session.snapshot"
        case .subscribe: "events.subscribe"
        }
    }

    func line(id: String) -> Data {
        var params: [String: Any] = [:]
        if case .subscribe(let subscriptions) = self {
            params["subscriptions"] = subscriptions.map(\.json)
        }
        let body: [String: Any] = ["id": id, "method": method, "params": params]
        var data = try! JSONSerialization.data(withJSONObject: body)
        data.append(0x0A)
        return data
    }
}

/// One newline-delimited line pushed by Herdr, reduced to what the companion
/// reacts to. Anything else is decoded as `.other` so unknown events and
/// fields never break the stream.
enum HerdrEvent: Equatable, Sendable {
    case agentStatusChanged(paneID: String, agent: String?, status: HerdrAgentStatus)
    case agentDetected(paneID: String, agent: String?, released: Bool)
    case paneRemoved(paneID: String)
    case paneMoved(previousPaneID: String, paneID: String)
    case other(String)

    private struct Envelope: Decodable {
        struct Payload: Decodable {
            struct Pane: Decodable {
                let paneID: String
                private enum CodingKeys: String, CodingKey { case paneID = "pane_id" }
            }

            let paneID: String?
            let agent: String?
            let agentStatus: HerdrAgentStatus?
            let released: Bool?
            let previousPaneID: String?
            let pane: Pane?

            private enum CodingKeys: String, CodingKey {
                case paneID = "pane_id"
                case agent
                case agentStatus = "agent_status"
                case released
                case previousPaneID = "previous_pane_id"
                case pane
            }
        }

        let event: String
        let data: Payload
    }

    init?(line: Data) {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: line) else { return nil }
        let data = envelope.data

        // Lifecycle events arrive as `pane_closed`; pane-scoped subscription
        // events arrive in the dotted subscription form, `pane.agent_status_changed`.
        switch envelope.event {
        case "pane.agent_status_changed", "pane_agent_status_changed":
            guard let paneID = data.paneID, let status = data.agentStatus else { return nil }
            self = .agentStatusChanged(paneID: paneID, agent: data.agent, status: status)
        case "pane_agent_detected":
            guard let paneID = data.paneID else { return nil }
            self = .agentDetected(paneID: paneID, agent: data.agent, released: data.released ?? false)
        case "pane_closed", "pane_exited":
            guard let paneID = data.paneID else { return nil }
            self = .paneRemoved(paneID: paneID)
        case "pane_moved":
            guard let previous = data.previousPaneID, let pane = data.pane else { return nil }
            self = .paneMoved(previousPaneID: previous, paneID: pane.paneID)
        default:
            self = .other(envelope.event)
        }
    }
}
