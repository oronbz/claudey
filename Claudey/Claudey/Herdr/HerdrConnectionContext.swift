import Foundation

/// Where the companion learns which Herdr socket to watch. The plugin writes
/// the context file on every activation; a developer launch without the
/// plugin falls back to the environment and then Herdr's default socket.
struct HerdrConnectionContext: Equatable, Sendable {
    let socketPath: String

    static var contextFileURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Claudey", isDirectory: true)
            .appendingPathComponent("herdr-connection.json")
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
