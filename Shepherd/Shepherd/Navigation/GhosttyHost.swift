import AppKit
import Carbon

/// Brings the Ghostty terminal hosting a Herdr client forward. The client is
/// found by process ancestry under Ghostty, never by directory or title, and
/// its terminal by the foreground pid and tty Ghostty's AppleScript dictionary
/// exposes. AppleScript runs on its own queue so a permission dialog never
/// freezes the animation; a refusal is remembered so macOS is not asked twice.
final class GhosttyHost {
    nonisolated static let bundleID = "com.mitchellh.ghostty"

    private let queue = DispatchQueue(label: "com.oronbz.Shepherd.ghostty")
    private nonisolated(unsafe) var automationRefused = false

    func activateHerdrTerminal(completion: @escaping @MainActor (Bool) -> Void) {
        guard let ghostty = NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).first else {
            return completion(false)
        }
        let ghosttyPID = ghostty.processIdentifier
        queue.async { [self] in
            let clients = HerdrClientProcesses.hosted(by: ghosttyPID)
            guard !clients.isEmpty else {
                return DispatchQueue.main.async { completion(false) }
            }
            let focused = focusTerminal(hosting: clients)
            DispatchQueue.main.async {
                if !focused || !ghostty.isActive { Self.bringForward(ghostty) }
                completion(true)
            }
        }
    }

    /// Launching an already running app is how `open -a` activates it, and
    /// unlike `activate(options:)` it is honoured from a non-activating panel.
    private static func bringForward(_ app: NSRunningApplication) {
        guard let url = app.bundleURL else {
            _ = app.activate(options: [])
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error { NSLog("Shepherd could not bring Ghostty forward: \(error)") }
        }
    }

    private nonisolated func focusTerminal(hosting clients: [HerdrClientProcesses.Client]) -> Bool {
        guard !automationRefused else { return false }
        switch GhosttyScripting.permission() {
        case noErr:
            break
        case OSStatus(errAEEventNotPermitted):
            automationRefused = true
            NSLog("Shepherd has no Automation permission for Ghostty; activating the app instead")
            return false
        case let status:
            NSLog("Shepherd could not check Automation permission for Ghostty: \(status)")
            return false
        }
        guard let terminals = GhosttyScripting.terminals() else { return false }
        let pids = Set(clients.map(\.pid))
        let ttys = Set(clients.compactMap(\.tty))
        guard let match = terminals.first(where: { pids.contains($0.pid) || ttys.contains($0.tty) }) else {
            NSLog("Shepherd found no Ghostty terminal hosting a Herdr client among \(terminals.count)")
            return false
        }
        let focused = GhosttyScripting.focus(terminalID: match.id)
        #if DEBUG
        NSLog("Shepherd Ghostty terminal \(match.id) (pid \(match.pid), \(match.tty)) focused: \(focused)")
        #endif
        return focused
    }
}

nonisolated enum GhosttyScripting {
    struct Terminal {
        let id: String
        let pid: pid_t
        let tty: String
    }

    static func permission() -> OSStatus {
        guard let target = NSAppleEventDescriptor(bundleIdentifier: GhosttyHost.bundleID).aeDesc else {
            return OSStatus(procNotFound)
        }
        let wildcard = AEEventClass(bitPattern: 0x2A2A2A2A)
        return AEDeterminePermissionToAutomateTarget(target, wildcard, AEEventID(wildcard), true)
    }

    static func terminals() -> [Terminal]? {
        let source = """
        tell application id "\(GhosttyHost.bundleID)"
            return {id of every terminal, pid of every terminal, tty of every terminal}
        end tell
        """
        guard let result = run(source), result.numberOfItems == 3,
              let ids = result.atIndex(1), let pids = result.atIndex(2), let ttys = result.atIndex(3)
        else { return nil }
        guard ids.numberOfItems > 0 else { return [] }
        return (1...ids.numberOfItems).compactMap { index in
            guard let id = ids.atIndex(index)?.stringValue,
                  let pid = pids.atIndex(index)?.int32Value,
                  let tty = ttys.atIndex(index)?.stringValue
            else { return nil }
            return Terminal(id: id, pid: pid, tty: tty)
        }
    }

    static func focus(terminalID: String) -> Bool {
        let escaped = terminalID.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application id "\(GhosttyHost.bundleID)"
            focus terminal id "\(escaped)"
        end tell
        """
        return run(source) != nil
    }

    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            NSLog("Shepherd could not talk to Ghostty: \(error)")
            return nil
        }
        return result
    }
}

nonisolated enum HerdrClientProcesses {
    struct Client {
        let pid: pid_t
        let tty: String?
    }

    /// Oldest first: an attached client outlives any `herdr` CLI call that
    /// briefly runs in another Ghostty shell.
    static func hosted(by hostPID: pid_t) -> [Client] {
        let processes = all()
        let parents = Dictionary(processes.map { ($0.pid, $0.parent) }, uniquingKeysWith: { first, _ in first })
        return processes
            .filter { $0.name == "herdr" && $0.tty != nil && descends($0.pid, from: hostPID, parents: parents) }
            .sorted { $0.startedAt < $1.startedAt }
            .map { Client(pid: $0.pid, tty: $0.tty) }
    }

    private struct Process {
        let pid: pid_t
        let parent: pid_t
        let name: String
        let tty: String?
        let startedAt: TimeInterval
    }

    private static func descends(_ pid: pid_t, from ancestor: pid_t, parents: [pid_t: pid_t]) -> Bool {
        var current = pid
        var hops = 0
        while let parent = parents[current], parent > 1, hops < 64 {
            if parent == ancestor { return true }
            current = parent
            hops += 1
        }
        return false
    }

    private static func all() -> [Process] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var buffer = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride + 8)
        size = buffer.count * MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, 4, &buffer, &size, nil, 0) == 0 else { return [] }
        let count = size / MemoryLayout<kinfo_proc>.stride
        return buffer.prefix(count).map { info in
            let name = withUnsafeBytes(of: info.kp_proc.p_comm) { raw in
                String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
            }
            let device = info.kp_eproc.e_tdev
            let tty = device == dev_t(bitPattern: UInt32.max) ? nil : devname(device, mode_t(S_IFCHR)).map { "/dev/" + String(cString: $0) }
            let started = info.kp_proc.p_starttime
            return Process(
                pid: info.kp_proc.p_pid, parent: info.kp_eproc.e_ppid, name: name, tty: tty,
                startedAt: TimeInterval(started.tv_sec) + TimeInterval(started.tv_usec) / 1_000_000
            )
        }
    }
}
