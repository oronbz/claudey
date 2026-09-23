import Foundation
import Testing
@testable import Shepherd

struct HerdrConnectionContextTests {
    @Test func theContextFileWinsOverEnvironmentAndDefault() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shepherd-\(UUID().uuidString).json")
        try Data("{\"socket_path\":\"/tmp/from-file.sock\",\"bin_path\":\"/opt/herdr\"}".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let context = HerdrConnectionContext.resolve(fileURL: url, environment: ["HERDR_SOCKET_PATH": "/tmp/env.sock"])

        #expect(context.socketPath == "/tmp/from-file.sock")
    }

    @Test func withoutAFileTheEnvironmentThenTheDefaultApply() {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("shepherd-missing-\(UUID().uuidString).json")

        #expect(HerdrConnectionContext.resolve(fileURL: missing, environment: ["HERDR_SOCKET_PATH": "/tmp/env.sock"]).socketPath == "/tmp/env.sock")
        #expect(HerdrConnectionContext.resolve(fileURL: missing, environment: [:]).socketPath.hasSuffix("/.config/herdr/herdr.sock"))
    }

    @Test func aConnectRequestIsConsumedOnce() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("shepherd-connect-\(UUID().uuidString)")
        #expect(HerdrConnectionContext.takeConnectRequest(fileURL: url) == false)

        try Data().write(to: url)

        #expect(HerdrConnectionContext.takeConnectRequest(fileURL: url) == true)
        #expect(HerdrConnectionContext.takeConnectRequest(fileURL: url) == false)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
