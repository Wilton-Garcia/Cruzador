import XCTest
@testable import CruzadorCore

struct NativeSmokeTrace {
    let root: URL
    func recordRuntime(_ runtime: WineRuntime) throws {
        let record: [String: Any] = ["formatVersion": 1, "runtime": runtime.root.path, "wine": runtime.wine.path, "server": runtime.server.path, "version": runtime.manifest.version]
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("runtime-control.json"), options: .atomic)
    }
    func phase(_ name: String) throws {
        let file = root.appendingPathComponent("phases.jsonl")
        if !FileManager.default.fileExists(atPath: file.path) { FileManager.default.createFile(atPath: file.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: file); defer { try? handle.close() }
        try handle.seekToEnd()
        var data = try JSONSerialization.data(withJSONObject: ["phase": name, "timestamp": Date().timeIntervalSince1970], options: [.sortedKeys])
        data.append(0x0a); try handle.write(contentsOf: data)
    }
}

/// Exercises the public library workflows using the already initialized real prefix.
/// Transfers retain their files for diagnosis, including removed copies.
struct NativeLibraryWorkflowScenario {
    let store: LibraryStore
    let runner: CommandRunner
    func run(bottleID: UUID) async throws -> [String: Any] {
        let trace = NativeSmokeTrace(root: store.root)
        let settingsStore = BottleSettingsStore(store: store)
        var library = try store.load()
        let index = try XCTUnwrap(library.bottles.firstIndex(where: { $0.id == bottleID }))
        var original = library.bottles[index]
        guard original.engine.kind == .packagedWine else { throw CruzadorError.invalid("O cenário exige o motor independente.") }
        try trace.phase("library-global-options")
        let settings = BottleSettings(executionOptions: LaunchOptions(workingDirectory: store.prefix(for: original).appendingPathComponent("drive_c").path, environment: ["CRUZADOR_GLOBAL": "GLOBAL_OK", "CRUZADOR_VALUE": "GLOBAL_VALUE"]))
        try await settingsStore.save(settings, bottleID: original.id, runner: runner)
        library = try store.load()
        let originalProbe = WindowsApp(name: "Cruzador workflow probe", path: store.prefix(for: original).appendingPathComponent("drive_c/windows/system32/cmd.exe").path, arguments: ["/c", "echo CRUZADOR_WORKFLOW_%CRUZADOR_GLOBAL%_%CRUZADOR_VALUE% && echo CRUZADOR_CWD_%CD%"], options: LaunchOptions(environment: ["CRUZADOR_VALUE": "LOCAL_OK"]))
        library.bottles[index].apps.append(originalProbe); try store.save(library)
        original = try store.load().bottles[index]
        let reference = LauncherReference(bottleID: original.id, appID: originalProbe.id)
        let shortcut = store.root.appendingPathComponent("original.cruzadorapp"); try reference.write(to: shortcut)
        guard case .launcher(let decoded) = try ExternalOpenTarget.parse(shortcut) else { throw CruzadorError.invalid("O atalho não foi reconhecido.") }
        let selected = try decoded.resolve(in: store.load())
        let originalRun = try await runProbe(selected.app, bottle: selected.bottle, name: "original-probe")

        let maintenance = BottleMaintenance(store: store, runner: runner)
        try trace.phase("library-duplicate")
        let copy = try await maintenance.duplicate(id: original.id, name: "Real copy")
        let copyProbe = try probe(in: copy)
        XCTAssertNotEqual(copyProbe.id, selected.app.id)
        XCTAssertEqual(copy.requestedSettings.executionOptions.workingDirectory, store.prefix(for: copy).appendingPathComponent("drive_c").path)
        let copiedRun = try await runProbe(copyProbe, bottle: copy, name: "copy-probe")
        let copyReference = LauncherReference(bottleID: copy.id, appID: copyProbe.id)

        try trace.phase("library-export")
        let package = store.root.appendingPathComponent("real-transfer.cruzadorbottle")
        try await maintenance.export(id: copy.id, destination: package)
        try trace.phase("library-remove-copy")
        let recovery = try await maintenance.remove(id: copy.id)
        XCTAssertThrowsError(try copyReference.resolve(in: store.load()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovery.appendingPathComponent("Prefix/system.reg").path))
        _ = try reference.resolve(in: store.load())

        try trace.phase("library-import")
        let imported = try maintenance.importBottle(from: package, engine: original.engine)
        XCTAssertNotEqual(imported.id, copy.id); XCTAssertFalse(store.isReady(imported))
        XCTAssertEqual(imported.state, .interrupted)
        XCTAssertEqual(imported.requestedSettings.executionOptions.workingDirectory, store.prefix(for: imported).appendingPathComponent("drive_c").path)
        let prepared = try await BottleLifecycle(store: store).prepare(id: imported.id, mode: .initialize, runner: runner, log: store.logsRoot.appendingPathComponent("import-prepare.log"))
        try prepared.requireSuccess()
        let readyImport = try XCTUnwrap(try store.load().bottles.first { $0.id == imported.id })
        let importedProbe = try probe(in: readyImport)
        let importedRun = try await runProbe(importedProbe, bottle: readyImport, name: "import-probe")
        var imported7zipExit: Int32?
        if let console = readyImport.apps.first(where: { $0.path.hasSuffix("/7z.exe") }) {
            try trace.phase("library-imported-7zip")
            let result = try await runner.run(EngineCommands.make(.run(console.launchRequest), bottle: readyImport, store: store), log: store.logsRoot.appendingPathComponent("import-7zip.log"))
            try result.requireSuccess()
            XCTAssertTrue(try String(contentsOf: result.log, encoding: .utf8).contains("7-Zip"))
            imported7zipExit = result.exitCode
        }
        try trace.phase("library-remove-import")
        _ = try await maintenance.remove(id: imported.id)
        XCTAssertEqual(try store.load().bottles.map(\.id), [original.id])
        _ = try reference.resolve(in: store.load())
        let idle = try await runner.run(EngineCommands.make(.waitForIdle, bottle: original, store: store), log: store.logsRoot.appendingPathComponent("workflow-final-wait.log"))
        try idle.requireSuccess()

        try trace.phase("library-diagnostics")
        let diagnostics = store.root.deletingLastPathComponent().appendingPathComponent("workflow-diagnostics-\(UUID())")
        let source = try Data(contentsOf: store.manifest)
        _ = try DiagnosticsService(store: store).export(to: diagnostics, bottleID: original.id, includeSourceLibrary: true, includeLogs: true)
        XCTAssertEqual(try Data(contentsOf: store.manifest), source)
        XCTAssertEqual(try Data(contentsOf: diagnostics.appendingPathComponent("source-library.json")), source)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let diagnosticReport = try decoder.decode(DiagnosticsReport.self, from: Data(contentsOf: diagnostics.appendingPathComponent("report.json")))
        for log in diagnosticReport.logs where log.status == "copied" {
            let file = diagnostics.appendingPathComponent(try XCTUnwrap(log.exportedPath))
            XCTAssertEqual(try ArtifactCache.sha256(of: file), log.sha256)
        }
        XCTAssertFalse(diagnosticReport.logs.contains { $0.status == "failed" })
        var report: [String: Any] = ["original_probe": originalRun, "copied_probe": copiedRun, "imported_probe": importedRun,
                                  "duplicate_id": copy.id.uuidString, "imported_id": imported.id.uuidString, "original_id": original.id.uuidString,
                                  "export_package": package.path, "removed_copy_recovery": recovery.path, "import_preparation_exit": prepared.exitCode,
                                  "removed_reference_rejected": true, "original_reference_resolved_after_transfers": true,
                                  "diagnostics": diagnostics.path, "diagnostics_source_preserved": true, "diagnostics_log_hashes_verified": true,
                                  "final_server_wait_exit": idle.exitCode]
        if let imported7zipExit { report["imported_7zip_exit"] = imported7zipExit }
        return report
    }
    private func probe(in bottle: Bottle) throws -> WindowsApp {
        let path = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32/cmd.exe").path
        return try XCTUnwrap(bottle.apps.first { $0.path == path })
    }
    private func runProbe(_ app: WindowsApp, bottle: Bottle, name: String) async throws -> [String: Any] {
        let result = try await runner.run(EngineCommands.make(.run(app.launchRequest), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent(name + ".log"))
        try result.requireSuccess()
        let output = try String(contentsOf: result.log, encoding: .utf8)
        let marker = output.contains("CRUZADOR_WORKFLOW_GLOBAL_OK_LOCAL_OK")
        let cwd = output.contains(#"CRUZADOR_CWD_C:\"#)
        XCTAssertTrue(marker, output); XCTAssertTrue(cwd, output)
        return ["exit": result.exitCode, "global_and_local_options_observed": marker, "working_directory_observed": cwd, "log": result.log.path]
    }
}
