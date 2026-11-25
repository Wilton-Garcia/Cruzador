import XCTest
@testable import CruzadorCore

final class BottleRecoveryTests: XCTestCase {
    func blockingBottle() throws -> (LibraryStore, Bottle, URL) {
        let root = try makeSynchronizationPackage()
        let store = LibraryStore(root: root.appendingPathComponent("library"))
        var bottle = Bottle(name: "Recovery", engine: Engine(kind: .packagedWine, path: root.path)); bottle.state = .ready
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        let prefix = store.prefix(for: bottle)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        try Data("registry".utf8).write(to: prefix.appendingPathComponent("system.reg"))
        let server = root.appendingPathComponent("bin/wineserver")
        let script = "#!/bin/sh\nif [ \"$1\" = -k ]; then touch \"$WINEPREFIX/stopped\"; exit 9; fi\nif [ ! -f \"$WINEPREFIX/stopped\" ]; then printf waiting; exec /bin/sleep 30; fi\n"
        try script.write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        return (store, bottle, server)
    }
    func cancelRunning(_ runner: CommandRunner, id: UUID) async throws {
        var started = false
        for _ in 0..<100 {
            if await runner.isRunning(operationID: id) { started = true; break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(started)
        let accepted = await runner.cancel(operationID: id); XCTAssertTrue(accepted)
    }
    func finishCleanup(_ runner: CommandRunner, id: UUID, server: URL) async throws {
        try "#!/bin/sh\nexit 0\n".write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        try await runner.retryCleanup(failedOperationID: id).requireSuccess()
    }
    func testUnconfirmedSettingsCleanupSurvivesReopeningAndKeepsOldMode() async throws {
        let (store, bottle, server) = try blockingBottle()
        let runner = CommandRunner(), id = UUID()
        let saving = Task { try await BottleSettingsStore(store: store).save(BottleSettings(synchronization: .msync), bottleID: bottle.id, runner: runner, operationID: id) }
        try await cancelRunning(runner, id: id)
        do { try await saving.value; XCTFail("Cleanup failure cannot commit settings") }
        catch { XCTAssertNotNil(BottleOperationRecovery.shutdownFailure(in: error)) }
        let reopened = LibraryStore(root: store.root), saved = try reopened.load().bottles[0]
        XCTAssertEqual(saved.requestedSettings.synchronization, .automatic)
        XCTAssertEqual(saved.state, .interrupted); XCTAssertNotNil(saved.lastError); XCTAssertNotNil(saved.lastLogPath)
        XCTAssertFalse(reopened.isReady(saved))
        let pending = await runner.pendingCleanupIDs(); XCTAssertEqual(pending, [id])
        try await finishCleanup(runner, id: id, server: server)
        XCTAssertEqual(try reopened.load().bottles[0].state, .interrupted)
    }
    private enum Workflow: CaseIterable, Sendable { case installer, maintenance, preparation }
    func testExecutionWorkflowsKeepUnconfirmedShutdownOnReopening() async throws {
        for workflow in Workflow.allCases {
            let (store, bottle, server) = try blockingBottle()
            let runner = CommandRunner(), id = UUID()
            let file = store.root.appendingPathComponent("input.msi")
            try Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]).write(to: file)
            let operation = Task {
                if workflow == .installer || workflow == .preparation {
                    // Use the same controlled executable as a blocking Wine client.
                    let wine = URL(fileURLWithPath: bottle.engine.path).appendingPathComponent("bin/wine")
                    try "#!/bin/sh\nprintf waiting; exec /bin/sleep 30\n".write(to: wine, atomically: true, encoding: .utf8)
                    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
                    if workflow == .installer {
                        _ = try await InstallationService(store: store).run(InstallationRequest(path: file.path), bottle: bottle, runner: runner, log: store.logsRoot.appendingPathComponent("installer.log"), operationID: id)
                    } else {
                        _ = try await BottleLifecycle(store: store).prepare(id: bottle.id, mode: .initialize, runner: runner, log: store.logsRoot.appendingPathComponent("prepare.log"), operationID: id)
                    }
                } else {
                    _ = try await BottleMaintenance(store: store, runner: runner, operationID: id).duplicate(id: bottle.id, name: "must not copy")
                }
            }
            try await cancelRunning(runner, id: id)
            do { try await operation.value; XCTFail("Failed cleanup cannot complete the operation") }
            catch { XCTAssertNotNil(BottleOperationRecovery.shutdownFailure(in: error)) }
            let reopened = LibraryStore(root: store.root), saved = try reopened.load().bottles[0]
            XCTAssertEqual(saved.state, workflow == .preparation ? .failed : .interrupted); XCTAssertFalse(reopened.isReady(saved))
            XCTAssertEqual(try reopened.load().bottles.count, 1)
            if workflow == .installer { XCTAssertEqual(saved.installations?.last?.status, .cancelled) }
            try await finishCleanup(runner, id: id, server: server)
        }
    }
    func testPreparationAndInstallerMetadataFailuresKeepCleanupFacts() async throws {
        for install in [true, false] {
            let (store, bottle, server) = try blockingBottle()
            let wine = URL(fileURLWithPath: bottle.engine.path).appendingPathComponent("bin/wine")
            try "#!/bin/sh\nprintf waiting; exec /bin/sleep 30\n".write(to: wine, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
            let file = store.root.appendingPathComponent("input.msi")
            try Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]).write(to: file)
            let runner = CommandRunner(), id = UUID()
            let operation = Task {
                if install { return try await InstallationService(store: store).run(InstallationRequest(path: file.path), bottle: bottle, runner: runner, log: store.logsRoot.appendingPathComponent("installer.log"), operationID: id) }
                return try await BottleLifecycle(store: store).prepare(id: bottle.id, mode: .initialize, runner: runner, log: store.logsRoot.appendingPathComponent("prepare.log"), operationID: id)
            }
            for _ in 0..<100 { if await runner.isRunning(operationID: id) { break }; try await Task.sleep(for: .milliseconds(10)) }
            let malformed = Data("{changed during operation".utf8); try malformed.write(to: store.manifest)
            try await cancelRunning(runner, id: id)
            do { _ = try await operation.value; XCTFail("Metadata failure cannot hide cleanup failure") }
            catch { XCTAssertNotNil(error as? BottleRecoveryError); XCTAssertNotNil(BottleOperationRecovery.shutdownFailure(in: error)) }
            XCTAssertEqual(try Data(contentsOf: store.manifest), malformed)
            try await finishCleanup(runner, id: id, server: server)
        }
    }
    func testMetadataFailureRetainsShutdownFactsAndMalformedSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LibraryStore(root: root); try store.prepare()
        let original = Data("{broken".utf8); try original.write(to: store.manifest)
        let phase = CommandPhaseResult(phase: "cancellation", executable: "/selected/server", arguments: ["-k"], exitCode: 9, launchError: nil)
        let shutdown = CommandRunnerError.cancelled(log: "/selected/log", cleanupFailures: ["server exit 9"], phases: [phase])
        do { try BottleOperationRecovery(store: store).record(shutdown, bottleID: UUID()); XCTFail("Invalid metadata cannot be overwritten") }
        catch {
            XCTAssertNotNil(error as? BottleRecoveryError)
            let retained = try XCTUnwrap(BottleOperationRecovery.shutdownFailure(in: error))
            if case .cancelled(let log, let failures, let phases) = retained {
                XCTAssertEqual(log, "/selected/log"); XCTAssertEqual(failures, ["server exit 9"]); XCTAssertEqual(phases, [phase])
            } else { XCTFail("Shutdown facts changed") }
        }
        XCTAssertEqual(try Data(contentsOf: store.manifest), original)
        XCTAssertFalse(try BottleOperationRecovery(store: store).record(CruzadorError.invalid("ordinary failure"), bottleID: UUID()))
    }
}
