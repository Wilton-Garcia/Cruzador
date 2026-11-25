import XCTest
@testable import CruzadorCore

final class BottleLifecycleTests: XCTestCase {
    func fixture() throws -> (BottleLifecycle, Engine) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let wine = root.appendingPathComponent("wine")
        let script = #"""
        #!/bin/sh
        mkdir -p "$WINEPREFIX/drive_c"
        printf '%s\n' "$2"
        if [ -f "$WINEPREFIX/fail" ]; then exit 5; fi
        """#
        let server = #"""
        #!/bin/sh
        printf registry > "$WINEPREFIX/system.reg"
        """#
        for (name, text) in [("wine", script), ("wineserver", server)] {
            let file = root.appendingPathComponent(name)
            try (text + "\n").write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        return (BottleLifecycle(store: LibraryStore(root: root.appendingPathComponent("data"))), Engine(kind: .wine, path: wine.path))
    }
    func testCreatePrepareRepairAndFailedRetryKeepIdentityAndFiles() async throws {
        let (lifecycle, engine) = try fixture()
        let bottle = try lifecycle.create(name: "  日本語 ../ jogos  ", engine: engine)
        XCTAssertEqual(bottle.name, "日本語 ../ jogos")
        XCTAssertEqual(lifecycle.store.health(of: bottle), .absent)
        let log = lifecycle.store.logsRoot.appendingPathComponent("prepare.log")
        _ = try await lifecycle.prepare(id: bottle.id, mode: .initialize, runner: CommandRunner(), log: log)
        XCTAssertEqual(try lifecycle.store.load().bottles[0].state, .ready)
        let prefix = lifecycle.store.prefix(for: bottle)
        let sentinel = prefix.appendingPathComponent("my-files")
        try Data("preserve".utf8).write(to: sentinel)
        _ = try await lifecycle.prepare(id: bottle.id, mode: .repair, runner: CommandRunner(), log: log)
        XCTAssertTrue(try String(contentsOf: log, encoding: .utf8).contains("--update"))
        try Data().write(to: prefix.appendingPathComponent("fail"))
        do {
            _ = try await lifecycle.prepare(id: bottle.id, mode: .repair, runner: CommandRunner(), log: log)
            XCTFail("Expected nonzero failure")
        } catch {}
        let failed = try lifecycle.store.load().bottles[0]
        XCTAssertEqual(failed.id, bottle.id); XCTAssertEqual(failed.state, .failed)
        XCTAssertNotNil(failed.lastError); XCTAssertEqual(failed.lastLogPath, log.path)
        XCTAssertEqual(try Data(contentsOf: sentinel), Data("preserve".utf8))
        try FileManager.default.removeItem(at: prefix.appendingPathComponent("fail"))
        _ = try await lifecycle.prepare(id: bottle.id, mode: .initialize, runner: CommandRunner(), log: log)
        XCTAssertEqual(try lifecycle.store.load().bottles[0].state, .ready)
        XCTAssertNil(try lifecycle.store.load().bottles[0].lastError)
    }
    func testInterruptedPreparationIsExplicitAndRecoveryIsIdempotent() throws {
        let (lifecycle, engine) = try fixture()
        let bottle = try lifecycle.create(name: "Interrupted", engine: engine)
        try lifecycle.recoverInterruptedPreparations()
        let saved = try Data(contentsOf: lifecycle.store.manifest)
        XCTAssertEqual(try lifecycle.store.load().bottles[0].state, .interrupted)
        XCTAssertEqual(lifecycle.store.health(of: bottle), .absent)
        try lifecycle.recoverInterruptedPreparations()
        XCTAssertEqual(try Data(contentsOf: lifecycle.store.manifest), saved)
    }
    func testRegistryDirectoryDoesNotMakePrefixReady() throws {
        let (lifecycle, engine) = try fixture()
        let bottle = try lifecycle.create(name: "Partial", engine: engine)
        let prefix = lifecycle.store.prefix(for: bottle)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("system.reg"), withIntermediateDirectories: true)
        XCTAssertEqual(lifecycle.store.health(of: bottle), .incomplete)
    }
}
