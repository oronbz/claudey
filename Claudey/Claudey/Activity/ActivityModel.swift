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
    private var nextOrder: UInt64 = 0

    func apply(_ event: ActivityEvent) -> ActivityUpdate {
        var finished: [SessionIdentity] = []

        switch event {
        case .connected(let records):
            isConnected = true
            sessions = records
            nextOrder = (records.map(\.changeOrder).max() ?? 0) + 1

        case .disconnected:
            isConnected = false
            sessions = []

        case .sessionAppeared(let record):
            sessions.removeAll { $0.identity.paneID == record.identity.paneID }
            sessions.append(SessionRecord(identity: record.identity, status: record.status, changeOrder: claimOrder()))

        case .statusChanged(let paneID, let status):
            guard let index = sessions.firstIndex(where: { $0.identity.paneID == paneID }) else { break }
            let previous = sessions[index].status
            guard previous != status else { break }
            sessions[index].status = status
            sessions[index].changeOrder = claimOrder()
            if previous == .working, status == .ready {
                finished.append(sessions[index].identity)
            }

        case .sessionRemoved(let paneID):
            sessions.removeAll { $0.identity.paneID == paneID }
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

    private func claimOrder() -> UInt64 {
        defer { nextOrder += 1 }
        return nextOrder
    }
}
