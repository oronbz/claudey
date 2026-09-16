import Foundation

struct HerdrConnectionContext: Equatable, Sendable {
    let socketPath: String

    static var contextFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Claudey", isDirectory: true)
            .appendingPathComponent("herdr-connection.json")
    }

    /// The plugin's Connect action leaves this marker; it is honoured once.
    static var connectRequestURL: URL {
        contextFileURL.deletingLastPathComponent().appendingPathComponent("connect-request")
    }

    static func takeConnectRequest(fileURL: URL = connectRequestURL) -> Bool {
        (try? FileManager.default.removeItem(at: fileURL)) != nil
    }

    static var defaultSocketPath: String {
        NSHomeDirectory() + "/.config/herdr/herdr.sock"
    }

    static func resolve(
        fileURL: URL = contextFileURL,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> HerdrConnectionContext {
        if let data = try? Data(contentsOf: fileURL),
           let file = try? JSONDecoder().decode(ContextFile.self, from: data),
           let path = file.socketPath, !path.isEmpty {
            return HerdrConnectionContext(socketPath: path)
        }
        if let path = environment["HERDR_SOCKET_PATH"], !path.isEmpty {
            return HerdrConnectionContext(socketPath: path)
        }
        return HerdrConnectionContext(socketPath: defaultSocketPath)
    }

    private struct ContextFile: Decodable {
        let socketPath: String?

        private enum CodingKeys: String, CodingKey {
            case socketPath = "socket_path"
        }
    }
}
