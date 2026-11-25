import XCTest
@testable import CruzadorCore

extension XCTestCase {
    func makeSynchronizationPackage() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bin"), withIntermediateDirectories: true)
        for name in ["wine", "wineserver"] {
            let file = root.appendingPathComponent("bin/" + name)
            try "#!/bin/sh\nexit 0\n".write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        }
        try Data("Fixture license".utf8).write(to: root.appendingPathComponent("LICENSE"))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let manifest = WineRuntimeManifest(formatVersion: 2, version: "fixture", sourceURL: "https://example.invalid", sourceRevision: "9f3f6447844add700bc0dde650e4f398fd5f69ab", architectures: ["test"], licenseFiles: ["LICENSE"], minimumMacOSVersion: RuntimeMacOSVersion(major: 14), features: ["msync"])
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("runtime.json"))
        return root
    }
}

final class SynchronizationTests: XCTestCase {
    func testGlobalOptionsMergeOnceAndSyncOverrideMustAgree() throws {
        let root = try makeSynchronizationPackage(), store = LibraryStore(root: root.appendingPathComponent("data"))
        var bottle = Bottle(name: "Settings", engine: Engine(kind: .packagedWine, path: root.path))
        bottle.configuration = BottleSettings(synchronization: .msync, executionOptions: LaunchOptions(workingDirectory: root.path, environment: ["GLOBAL": "literal $HOME", "VALUE": "global"]))
        let app = root.appendingPathComponent("app.exe"); try Data().write(to: app)
        let request = LaunchRequest(path: app.path, options: LaunchOptions(environment: ["VALUE": "local", "WINEMSYNC": "2"]))
        let plan = try EngineCommands.make(.run(request), bottle: bottle, store: store)
        XCTAssertEqual(plan.primary.environment["GLOBAL"], "literal $HOME")
        XCTAssertEqual(plan.primary.environment["VALUE"], "local")
        XCTAssertEqual(plan.primary.environment["WINEMSYNC"], "2")
        XCTAssertEqual(plan.primary.workingDirectory?.path, root.path)
        XCTAssertNil(plan.cancellation[0].environment["GLOBAL"])
        XCTAssertThrowsError(try EngineCommands.make(.run(LaunchRequest(path: app.path, options: LaunchOptions(environment: ["WINEMSYNC": "0"]))), bottle: bottle, store: store))
        bottle.configuration?.executionOptions.workingDirectory = "/missing-\(UUID())"
        XCTAssertThrowsError(try EngineCommands.make(.tool("cmd"), bottle: bottle, store: store))
        XCTAssertNoThrow(try EngineCommands.make(.waitForIdle, bottle: bottle, store: store))
    }
    func testUnsupportedModesAndOlderGraphicsSettingsRemainExplicit() throws {
        let decoded = try JSONDecoder().decode(BottleSettings.self, from: Data(#"{"graphics":"openGL"}"#.utf8))
        XCTAssertEqual(decoded.synchronization, .automatic); XCTAssertEqual(decoded.executionOptions, LaunchOptions())
        let engine = Engine(kind: .wine, path: "/bin/sh")
        XCTAssertFalse(SynchronizationConfiguration.supportsMSync(engine: engine))
        XCTAssertThrowsError(try SynchronizationConfiguration.environment(settings: BottleSettings(synchronization: .msync), engine: engine))
        XCTAssertThrowsError(try SynchronizationConfiguration.environment(settings: BottleSettings(executionOptions: LaunchOptions(environment: ["WINEMSYNC": "1"])), engine: engine))
        let root = try makeSynchronizationPackage(), supported = Engine(kind: .packagedWine, path: root.path)
        XCTAssertEqual(try SynchronizationConfiguration.environment(settings: BottleSettings(), engine: supported), ["WINEMSYNC": "0"])
        XCTAssertThrowsError(try SynchronizationConfiguration.environment(settings: BottleSettings(synchronization: .msync, executionOptions: LaunchOptions(environment: ["WINEMSYNC": "0"])), engine: supported))
        XCTAssertThrowsError(try SynchronizationConfiguration.environment(settings: BottleSettings(executionOptions: LaunchOptions(environment: ["WINEMSYNC": " 1"])), engine: supported))
    }
    func testSettingsCommitOnlyAfterSuccessfulWaitAndAreIdempotent() async throws {
        let root = try makeSynchronizationPackage(), store = LibraryStore(root: root.appendingPathComponent("data"))
        let bottle = Bottle(name: "Wait", engine: Engine(kind: .packagedWine, path: root.path))
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        try FileManager.default.createDirectory(at: store.prefix(for: bottle), withIntermediateDirectories: true)
        let server = root.appendingPathComponent("bin/wineserver")
        func script(_ text: String) throws { try text.write(to: server, atomically: true, encoding: .utf8); try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path) }
        try script("#!/bin/sh\nexit 9\n")
        let service = BottleSettingsStore(store: store), runner = CommandRunner(), settings = BottleSettings(synchronization: .msync)
        do { try await service.save(settings, bottleID: bottle.id, runner: runner); XCTFail("Failed wait must preserve settings") } catch CommandRunnerError.failed {}
        XCTAssertEqual(try store.load().bottles[0].requestedSettings.synchronization, .automatic)
        try script("#!/bin/sh\nprintf waited\n")
        try await service.save(settings, bottleID: bottle.id, runner: runner)
        XCTAssertEqual(try store.load().bottles[0].requestedSettings, settings)
        let before = try Data(contentsOf: store.manifest)
        try FileManager.default.removeItem(at: server)
        // Manifest resolution still requires the server, so restore it with failure to prove no wait.
        try script("#!/bin/sh\nexit 9\n")
        try await service.save(settings, bottleID: bottle.id, runner: runner)
        XCTAssertEqual(try Data(contentsOf: store.manifest), before)
    }
    func testCancelledSettingsWaitNeverCommitsNewMode() async throws {
        let root = try makeSynchronizationPackage(), store = LibraryStore(root: root.appendingPathComponent("data"))
        let bottle = Bottle(name: "Cancel", engine: Engine(kind: .packagedWine, path: root.path))
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        try FileManager.default.createDirectory(at: store.prefix(for: bottle), withIntermediateDirectories: true)
        let server = root.appendingPathComponent("bin/wineserver")
        // First wait blocks; cleanup -k releases subsequent waits. No detached child remains.
        let script = "#!/bin/sh\nif [ \"$1\" = -k ]; then touch \"$WINEPREFIX/stopped\"; exit 0; fi\nif [ ! -f \"$WINEPREFIX/stopped\" ]; then printf waiting; exec /bin/sleep 30; fi\n"
        try script.write(to: server, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: server.path)
        let runner = CommandRunner(), id = UUID()
        let saving = Task { try await BottleSettingsStore(store: store).save(BottleSettings(synchronization: .msync), bottleID: bottle.id, runner: runner, operationID: id) }
        var started = false
        for _ in 0..<100 {
            if await runner.isRunning(operationID: id) { started = true; break }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(started)
        _ = await runner.cancel(operationID: id)
        do { try await saving.value; XCTFail("Cancellation is not a successful wait") } catch CommandRunnerError.cancelled {}
        XCTAssertEqual(try store.load().bottles[0].requestedSettings.synchronization, .automatic)
    }
    func testRealMSyncRuntimeAndServerMode() async throws {
        guard let path = ProcessInfo.processInfo.environment["CRUZADOR_MSYNC_RUNTIME"], let rootPath = ProcessInfo.processInfo.environment["CRUZADOR_MSYNC_ROOT"] else { throw XCTSkip("Defina CRUZADOR_MSYNC_RUNTIME e CRUZADOR_MSYNC_ROOT (pasta nova) para testar MSync real.") }
        guard rootPath.hasPrefix("/"), !FileManager.default.fileExists(atPath: rootPath) else { throw CruzadorError.invalid("O cenário exige uma pasta nova absoluta.") }
        let engine = Engine(kind: .packagedWine, path: path)
        XCTAssertTrue(SynchronizationConfiguration.supportsMSync(engine: engine))
        let store = LibraryStore(root: URL(fileURLWithPath: rootPath)), lifecycle = BottleLifecycle(store: store), runner = CommandRunner()
        var bottle = try lifecycle.create(name: "MSync real", engine: engine)
        try NativeSmokeTrace(root: store.root).recordRuntime(WineRuntime(root: URL(fileURLWithPath: engine.path)))
        try await BottleSettingsStore(store: store).save(BottleSettings(synchronization: .msync), bottleID: bottle.id, runner: runner)
        let operationID = UUID()
        let watchdog = Task { try? await Task.sleep(for: .seconds(120)); if !Task.isCancelled { await runner.cancel(operationID: operationID) } }
        defer { watchdog.cancel() }
        let initialized = try await lifecycle.prepare(id: bottle.id, mode: .initialize, runner: runner, log: store.logsRoot.appendingPathComponent("initialize.log"), operationID: operationID)
        try initialized.requireSuccess()
        var observations: [[String: Any]] = []
        var cancellation: [String: Any] = [:]
        for mode in [SynchronizationMode.msync, .server] {
            let settings = BottleSettings(synchronization: mode, executionOptions: LaunchOptions(workingDirectory: store.root.path, environment: ["CRUZADOR_GLOBAL": "GLOBAL_OK"]))
            try await BottleSettingsStore(store: store).save(settings, bottleID: bottle.id, runner: runner, operationID: operationID)
            bottle = try store.load().bottles[0]
            let cmd = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32/cmd.exe")
            let result = try await runner.run(EngineCommands.make(.run(LaunchRequest(path: cmd.path, arguments: ["/c", "echo", "CRUZADOR_SYNC_%WINEMSYNC%_%CRUZADOR_GLOBAL%"])), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("\(mode.rawValue).log"), operationID: operationID)
            try result.requireSuccess()
            let text = try String(contentsOf: result.log, encoding: .utf8)
            let marker = "CRUZADOR_SYNC_\(mode == .msync ? "1" : "0")_GLOBAL_OK"
            XCTAssertTrue(text.contains(marker), text)
            if mode == .msync { XCTAssertTrue(text.contains("msync: up and running."), text) }
            observations.append(["mode": mode.rawValue, "marker": marker, "log": text, "exit": result.exitCode, "cancelled": result.cancelled])
            if mode == .msync {
                let cancelLog = store.logsRoot.appendingPathComponent("msync-cancel.log")
                let plan = try EngineCommands.make(.run(LaunchRequest(path: cmd.path, arguments: ["/c", "echo CRUZADOR_MSYNC_WAIT_READY && notepad.exe"])), bottle: bottle, store: store)
                let running = Task { try await runner.run(plan, log: cancelLog, operationID: operationID) }
                var started = false
                for _ in 0..<500 {
                    if (try? String(contentsOf: cancelLog, encoding: .utf8))?.contains("CRUZADOR_MSYNC_WAIT_READY") == true { started = true; break }
                    try await Task.sleep(for: .milliseconds(20))
                }
                _ = await runner.cancel(operationID: operationID)
                let cancelled = try await running.value
                XCTAssertTrue(started); XCTAssertTrue(cancelled.cancelled); XCTAssertTrue(cancelled.cleanupFailures.isEmpty)
                let codes = cancelled.phases.filter { $0.phase == "cancellation" }.compactMap(\.exitCode)
                XCTAssertEqual(codes, [0, 0])
                let after = try await runner.run(EngineCommands.make(.run(LaunchRequest(path: cmd.path, arguments: ["/c", "echo", "CRUZADOR_AFTER_MSYNC_CANCEL"])), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("msync-after-cancel.log"), operationID: operationID)
                try after.requireSuccess()
                let marker = try String(contentsOf: after.log, encoding: .utf8).contains("CRUZADOR_AFTER_MSYNC_CANCEL")
                XCTAssertTrue(marker)
                cancellation = ["cancelled": cancelled.cancelled, "cleanup_codes": codes, "after_cancel_exit": after.exitCode, "after_cancel_marker": marker]
            }
        }
        let stopped = try await runner.run(EngineCommands.make(.waitForIdle, bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("final-wait.log"), operationID: operationID)
        try stopped.requireSuccess()
        try JSONSerialization.data(withJSONObject: ["formatVersion": 2, "runtime": path, "root": rootPath, "initialization_exit": initialized.exitCode, "observations": observations, "cancellation": cancellation, "watchdog_seconds": 120, "server_wait_exit": stopped.exitCode], options: [.prettyPrinted, .sortedKeys]).write(to: store.root.appendingPathComponent("msync-observations.json"))
    }
}
