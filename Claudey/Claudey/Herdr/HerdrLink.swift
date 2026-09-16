import Foundation

/// Remembers whether the owner wants Claudey watching Herdr. Off survives
/// automatic retry, plugin startup hooks and relaunches; only the menu or the
/// plugin's explicit Connect action turns it back on.
final class ConnectionPreferenceStore {
    private static let key = "herdrConnectionEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults.object(forKey: Self.key) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}

final class HerdrLink {
    private let connection: HerdrConnection
    private let preference: ConnectionPreferenceStore
    private let takeConnectRequest: () -> Bool

    init(
        connection: HerdrConnection,
        preference: ConnectionPreferenceStore = ConnectionPreferenceStore(),
        takeConnectRequest: @escaping () -> Bool = { HerdrConnectionContext.takeConnectRequest() }
    ) {
        self.connection = connection
        self.preference = preference
        self.takeConnectRequest = takeConnectRequest
    }

    var isEnabled: Bool { preference.isEnabled }

    /// Launch and every plugin reopen: a startup hook only refreshes a
    /// connection the owner still wants; the Connect action's marker overrides
    /// a disconnect.
    func activate() {
        if takeConnectRequest() {
            connect()
        } else if preference.isEnabled {
            connection.refresh()
        }
    }

    func connect() {
        preference.isEnabled = true
        connection.refresh()
    }

    func disconnect() {
        preference.isEnabled = false
        connection.stop()
    }
}
