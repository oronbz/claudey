import Foundation

struct ActivityUpdate: Equatable {
    let state: CompanionAnimation
    let finished: [SessionIdentity]
}

/// Aggregates the sessions Herdr reports into the one state Claudey shows.
/// Only a live working → ready transition of the same occupant counts as
/// finishing; snapshots, reconnects and replacements set a new baseline.
final class ActivityModel {
    private(set) var sessions: [SessionRecord] = []
    private(set) var isConnected = false
    private var lastChange: [String: Int] = [:]
    private var sequence = 0

    func apply(_ event: ActivityEvent) -> ActivityUpdate {
        var finished: [SessionIdentity] = []
        sequence += 1

        switch event {
        case .connected(let records):
            isConnected = true
            sessions = records
            lastChange = Dictionary(records.map { ($0.identity.paneID, sequence) }, uniquingKeysWith: { _, last in last })

        case .disconnected:
            isConnected = false
            sessions = []
            lastChange = [:]

        case .sessionAppeared(let record):
            sessions.removeAll { $0.identity.paneID == record.identity.paneID }
            sessions.append(record)
            lastChange[record.identity.paneID] = sequence

        case .statusChanged(let paneID, let status):
            guard let index = sessions.firstIndex(where: { $0.identity.paneID == paneID }) else { break }
            let previous = sessions[index].status
            guard previous != status else { break }
            sessions[index].status = status
            lastChange[paneID] = sequence
            if previous == .working, status == .ready {
                finished.append(sessions[index].identity)
            }

        case .sessionRemoved(let paneID):
            sessions.removeAll { $0.identity.paneID == paneID }
            lastChange.removeValue(forKey: paneID)
        }

        return ActivityUpdate(state: state, finished: finished)
    }

    var state: CompanionAnimation {
        guard isConnected else { return .resting }
        let statuses = sessions.map(\.status)
        if statuses.contains(.needsYou) { return .needsYou }
        if statuses.contains(.working) { return .working }
        if statuses.contains(.ready) { return .idle }
        return .resting
    }

    /// The session a held questioning pose points at: the pinned one while it
    /// still needs you, otherwise the most recently changed waiting session.
    func waitingSession(preferring pinned: SessionIdentity?) -> SessionIdentity? {
        if let pinned, sessions.contains(where: { $0.identity == pinned && $0.status == .needsYou }) {
            return pinned
        }
        return mostRecent(sessions.filter { $0.status == .needsYou })?.identity
    }

    /// The pinned waiting session is resolved by the director on every event,
    /// so it is trusted here. A celebrated session that has since closed or
    /// changed occupant yields nil rather than the next best session.
    func navigationTarget(waiting: SessionIdentity?, celebrating: SessionIdentity?) -> SessionIdentity? {
        guard isConnected else { return nil }

        if let waiting { return waiting }
        if let celebrating {
            return sessions.contains { $0.identity == celebrating } ? celebrating : nil
        }
        return mostRecent(sessions)?.identity
    }

    private func mostRecent(_ candidates: [SessionRecord]) -> SessionRecord? {
        candidates.max { rank($0) < rank($1) }
    }

    private func rank(_ record: SessionRecord) -> (Int, Int) {
        let liveliness: Int = switch record.status {
        case .needsYou: 3
        case .working: 2
        case .ready: 1
        case .uncertain: 0
        }
        return (lastChange[record.identity.paneID] ?? 0, liveliness)
    }
}
