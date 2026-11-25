import XCTest
@testable import CruzadorCore

extension BottleMaintenanceTests {
    func testRebootUsesSelectedPrefixAndFinalizationControlsReadiness() async throws {
        let (maintenance, bottle) = try fixture()
        let store = maintenance.store, runner = CommandRunner()
        let plan = try EngineCommands.make(.reboot, bottle: bottle, store: store)
        XCTAssertEqual(plan.primary.arguments, ["wineboot", "--restart"])
        XCTAssertEqual(plan.prerequisites.map(\.arguments), [["-w"]])
        XCTAssertEqual(plan.primary.environment["WINEPREFIX"], store.prefix(for: bottle).path)
        XCTAssertEqual(plan.finalization.map(\.arguments), [["-w"]])
        let lifecycle = BottleLifecycle(store: store)
        let done = try await lifecycle.prepare(id: bottle.id, mode: .reboot, runner: runner, log: store.logsRoot.appendingPathComponent("reboot.log"))
        try done.requireSuccess(); XCTAssertEqual(try store.load().bottles[0].state, .ready)
        let server = URL(fileURLWithPath: bottle.engine.path).deletingLastPathComponent().appendingPathComponent("wineserver")
        try "#!/bin/sh\nexit 9\n".write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        let marker = store.root.appendingPathComponent("should-not-restart")
        try "#!/bin/sh\ntouch '\(marker.path)'\n".write(toFile: bottle.engine.path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bottle.engine.path)
        do { _ = try await lifecycle.prepare(id: bottle.id, mode: .reboot, runner: runner, log: store.logsRoot.appendingPathComponent("failed-reboot.log")); XCTFail("Finalization must succeed") } catch CommandRunnerError.failed {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertEqual(try store.load().bottles[0].state, .failed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.prefix(for: bottle).appendingPathComponent("drive_c/test.exe").path))
    }
}

extension BottleMaintenanceTests {
    func testCancellationDuringRebootPrerequisiteNeverStartsRestart() async throws {
        let (maintenance, bottle) = try fixture()
        let store = maintenance.store, runner = CommandRunner(), operation = UUID()
        let marker = store.root.appendingPathComponent("restart-started")
        try "#!/bin/sh\ntouch '\(marker.path)'\n".write(toFile: bottle.engine.path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bottle.engine.path)
        let server = URL(fileURLWithPath: bottle.engine.path).deletingLastPathComponent().appendingPathComponent("wineserver")
        try "#!/bin/sh\nif [ \"$1\" = -k ]; then touch \"$WINEPREFIX/reboot-stopped\"; exit 0; fi\nif [ ! -f \"$WINEPREFIX/reboot-stopped\" ]; then printf waiting; exec /bin/sleep 30; fi\nexit 0\n".write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        let log = store.logsRoot.appendingPathComponent("cancel-reboot.log")
        let running = Task { try await BottleLifecycle(store: store).prepare(id: bottle.id, mode: .reboot, runner: runner, log: log, operationID: operation) }
        var started = false
        for _ in 0..<300 {
            if (try? String(contentsOf: log, encoding: .utf8))?.contains("waiting") == true { started = true; break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(started)
        _ = await runner.cancel(operationID: operation)
        do { _ = try await running.value; XCTFail("Cancellation cannot start the restart") }
        catch CommandRunnerError.cancelled(_, let failures, let phases) {
            XCTAssertTrue(failures.isEmpty)
            XCTAssertFalse(phases.contains { $0.phase == "primary" })
            XCTAssertEqual(phases.filter { $0.phase == "cancellation" }.compactMap(\.exitCode), [0, 0])
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
        XCTAssertEqual(try store.load().bottles[0].state, .failed)
        let pending = await runner.pendingCleanupIDs(); XCTAssertTrue(pending.isEmpty)
    }
}
