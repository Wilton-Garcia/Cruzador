import XCTest
@testable import CruzadorCore

final class CommandRunnerTests: XCTestCase {
    func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func script(_ text: String, root: URL, name: String) throws -> Command {
        let path = root.appendingPathComponent(name)
        try ("#!/bin/sh\n" + text + "\n").write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        return Command(executable: path, arguments: [], environment: ["MARKER": root.appendingPathComponent(name + ".started").path, "ROOT": root.path])
    }
    func waitForMarker(_ path: URL) async -> Bool {
        for _ in 0..<200 {
            if FileManager.default.fileExists(atPath: path.path) { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
    func testCancellationDuringFinalizationKeepsCleanupAndRejectsStaleIDs() async throws {
        let root = try root(), runner = CommandRunner(), id = UUID()
        let primary = try script("printf primary", root: root, name: "primary")
        let finalizer = try script("trap 'exit 0' TERM\ntouch \"$MARKER\"\nwhile :; do /bin/sleep 0.02; done", root: root, name: "finalizer")
        let cleanup = try script("printf cleanup\ntouch \"$ROOT/cleaned\"", root: root, name: "cleanup")
        let plan = EnginePlan(primary: primary, finalization: [finalizer], cancellation: [cleanup])
        let task = Task { try await runner.run(plan, log: root.appendingPathComponent("run.log"), operationID: id) }
        let started = await waitForMarker(root.appendingPathComponent("finalizer.started"))
        if !started { await runner.cancel(operationID: id); _ = try? await task.value; XCTFail("Finalizer did not start"); return }
        do {
            _ = try await runner.run(primary, log: root.appendingPathComponent("busy.log"))
            XCTFail("Concurrent work must be rejected")
        } catch CommandRunnerError.busy {}
        let stale = await runner.cancel(operationID: UUID()); XCTAssertFalse(stale)
        let accepted = await runner.cancel(operationID: id); XCTAssertTrue(accepted)
        let result = try await task.value
        XCTAssertTrue(result.cancelled); XCTAssertTrue(result.cleanupFailures.isEmpty)
        XCTAssertEqual(result.exitCode, 0) // A successful callback/exit does not undo cancellation.
        XCTAssertThrowsError(try result.requireSuccess())
        XCTAssertEqual(result.phases.map(\.phase), ["primary", "finalization", "cancellation"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("cleaned").path))
        let log = try String(contentsOf: result.log, encoding: .utf8)
        XCTAssertTrue(log.contains("primary")); XCTAssertTrue(log.contains("cleanup"))
        let late = await runner.cancel(operationID: id); XCTAssertFalse(late)
        let next = try await runner.run(primary, log: root.appendingPathComponent("next.log"))
        XCTAssertFalse(next.cancelled); XCTAssertEqual(next.exitCode, 0)
    }
    func testCleanupFailureRetainsRecoveryAndRetryRemovesItOnlyAfterSuccess() async throws {
        let root = try root(), runner = CommandRunner(), id = UUID()
        let primary = try script("touch \"$MARKER\"\nexec /bin/sleep 60", root: root, name: "primary")
        let cleanup = try script("if [ ! -f \"$ROOT/retry\" ]; then touch \"$ROOT/retry\"; exit 4; fi\nprintf recovered", root: root, name: "cleanup")
        let last = try script("touch \"$ROOT/final-cleanup\"", root: root, name: "last")
        let task = Task { try await runner.run(EnginePlan(primary: primary, cancellation: [cleanup, last]), log: root.appendingPathComponent("run.log"), operationID: id) }
        let started = await waitForMarker(root.appendingPathComponent("primary.started"))
        if !started { await runner.cancel(operationID: id); _ = try? await task.value; XCTFail("Primary did not start"); return }
        await runner.cancel(operationID: id)
        let result = try await task.value
        XCTAssertTrue(result.cancelled); XCTAssertEqual(result.cleanupFailures.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("final-cleanup").path))
        let pending = await runner.pendingCleanupIDs(); XCTAssertEqual(pending, [id])
        do { _ = try await runner.run(last, log: root.appendingPathComponent("blocked.log")); XCTFail("Pending cleanup must block new work") } catch {}
        try FileManager.default.removeItem(at: root.appendingPathComponent("retry"))
        do { _ = try await runner.retryCleanup(failedOperationID: id); XCTFail("Expected retry failure") } catch {}
        let retained = await runner.pendingCleanupIDs(); XCTAssertEqual(retained, [id])
        let recovered = try await runner.retryCleanup(failedOperationID: id)
        try recovered.requireSuccess()
        let remaining = await runner.pendingCleanupIDs(); XCTAssertTrue(remaining.isEmpty)
    }
    func testLaunchFailureStillRunsAllFinalizersAndKeepsPartialFacts() async throws {
        let root = try root(), runner = CommandRunner()
        let absent = Command(executable: root.appendingPathComponent("absent"), arguments: [], environment: [:])
        let failed = try script("exit 8", root: root, name: "failed")
        let last = try script("touch \"$ROOT/finalized\"", root: root, name: "last")
        do {
            _ = try await runner.run(EnginePlan(primary: absent, finalization: [failed, last]), log: root.appendingPathComponent("run.log"))
            XCTFail("Expected launch failure")
        } catch CommandRunnerError.failed(_, let phases) {
            XCTAssertEqual(phases.count, 3); XCTAssertNil(phases[0].exitCode); XCTAssertNotNil(phases[0].launchError)
            XCTAssertEqual(phases[1].exitCode, 8); XCTAssertEqual(phases[2].exitCode, 0)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("finalized").path))
    }
    func testTaskCancelledBeforeLaunchCreatesNoProcessOrLog() async throws {
        let root = try root(), runner = CommandRunner()
        let command = try script("touch \"$MARKER\"", root: root, name: "never")
        let log = root.appendingPathComponent("never.log")
        let task = Task {
            try await Task.sleep(for: .milliseconds(100))
            return try await runner.run(command, log: log)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected task cancellation") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: log.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("never.started").path))
    }
    func testTaskCancellationAfterLaunchAwaitsCleanup() async throws {
        let root = try root(), runner = CommandRunner()
        let primary = try script("touch \"$MARKER\"\nexec /bin/sleep 60", root: root, name: "primary")
        let cleanup = try script("touch \"$ROOT/task-cleaned\"", root: root, name: "cleanup")
        let id = UUID()
        let task = Task { try await runner.run(EnginePlan(primary: primary, cancellation: [cleanup]), log: root.appendingPathComponent("task.log"), operationID: id) }
        let started = await waitForMarker(root.appendingPathComponent("primary.started"))
        if !started { await runner.cancel(operationID: id); _ = try? await task.value; XCTFail("Primary did not start"); return }
        task.cancel()
        let result = try await task.value
        XCTAssertTrue(result.cancelled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("task-cleaned").path))
        let running = await runner.isRunning(operationID: id); XCTAssertFalse(running)
    }

}
