import XCTest
@testable import CruzadorCore

final class RetinaTests: XCTestCase {
    func fixture() throws -> (LibraryStore, Bottle, URL) {
        let root = try makeSynchronizationPackage()
        let manifest = root.appendingPathComponent("runtime.json")
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any]); json["version"] = "11.21"
        try JSONSerialization.data(withJSONObject: json).write(to: manifest)
        let store = LibraryStore(root: root.appendingPathComponent("data"))
        var bottle = Bottle(name: "Retina", engine: Engine(kind: .packagedWine, path: root.path)); bottle.state = .ready
        try FileManager.default.createDirectory(at: store.prefix(for: bottle).appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        try Data("registry".utf8).write(to: store.prefix(for: bottle).appendingPathComponent("system.reg"))
        let user = store.prefix(for: bottle).appendingPathComponent("user.reg")
        try "WINE REGISTRY Version 2\n".write(to: user, atomically: true, encoding: .utf8)
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        return (store, bottle, user)
    }
    func testRegistryOwnsRetinaAndUnsupportedOrAmbiguousValuesRemainUnknown() throws {
        let (store, bottle, user) = try fixture(), service = RetinaConfiguration(store: store)
        XCTAssertEqual(try service.saved(in: bottle).mode, .automatic)
        func write(_ values: String) throws { try ("WINE REGISTRY Version 2\n\n[Software\\\\Wine\\\\Mac Driver]\n" + values + "\n").write(to: user, atomically: true, encoding: .utf8) }
        try write("\"RetinaMode\"=\"Y\"")
        XCTAssertEqual(try service.saved(in: bottle).mode, .enabled)
        try write("\"RetinaMode\"=\"N\"")
        XCTAssertEqual(try service.saved(in: bottle).mode, .disabled)
        try write("\"RetinaMode\"=dword:00000001")
        XCTAssertNil(try service.saved(in: bottle).mode)
        try write("\"RetinaMode\"=\"Y\"\n\"retinamode\"=\"N\"")
        XCTAssertNil(try service.saved(in: bottle).mode)
        try "invalid".write(to: user, atomically: true, encoding: .utf8)
        XCTAssertNil(try service.saved(in: bottle).mode)
    }
    func testWaitFailurePreservesRegistryAndIdempotentDefaultDoesNotWriteBackup() async throws {
        let (store, bottle, user) = try fixture(), service = RetinaConfiguration(store: store)
        let server = URL(fileURLWithPath: bottle.engine.path).appendingPathComponent("bin/wineserver")
        try "#!/bin/sh\nexit 9\n".write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        let original = try Data(contentsOf: user)
        do { _ = try await service.apply(.enabled, bottleID: bottle.id, runner: CommandRunner(), log: store.logsRoot.appendingPathComponent("failed.log")); XCTFail("Wait must succeed") } catch CommandRunnerError.failed {}
        XCTAssertEqual(try Data(contentsOf: user), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.root.appendingPathComponent("Backups").path))
        try "#!/bin/sh\nexit 0\n".write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        let unchanged = try await service.apply(.automatic, bottleID: bottle.id, runner: CommandRunner(), log: store.logsRoot.appendingPathComponent("same.log"))
        XCTAssertEqual(unchanged.mode, .automatic); XCTAssertEqual(try Data(contentsOf: user), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.root.appendingPathComponent("Backups").path))
    }
}
