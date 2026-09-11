import Foundation

/// Where a session lives in Herdr. The pane ID is the stable public handle;
/// the rest is kept so navigation can validate a target before focusing it
/// rather than guessing between sessions that share a project or title.
struct SessionIdentity: Equatable, Sendable {
    let paneID: String
    let terminalID: String
    let workspaceID: String
    let tabID: String
    let agent: String?
    let agentSession: String?
}

enum SessionStatus: Equatable, Sendable {
    case working
    case needsYou
    case ready
    case uncertain
}

struct SessionRecord: Equatable, Sendable {
    let identity: SessionIdentity
    var status: SessionStatus
    var changeOrder: UInt64
}

enum ActivityEvent: Equatable, Sendable {
    case connected([SessionRecord])
    case sessionAppeared(SessionRecord)
    case statusChanged(paneID: String, status: SessionStatus)
    case sessionRemoved(paneID: String)
    case disconnected
}
