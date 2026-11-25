import XCTest
@testable import CruzadorCore

final class PackagedNativeSmokeTests: XCTestCase {
    func testRealPackagedWineRuns32And64BitPrograms() async throws {
        guard let runtimePath = ProcessInfo.processInfo.environment["CRUZADOR_PACKAGED_RUNTIME"],
              let rootPath = ProcessInfo.processInfo.environment["CRUZADOR_PACKAGED_SMOKE_ROOT"] else {
            throw XCTSkip("Defina CRUZADOR_PACKAGED_RUNTIME e CRUZADOR_PACKAGED_SMOKE_ROOT para testar o motor próprio real.")
        }
        guard rootPath.hasPrefix("/"), !FileManager.default.fileExists(atPath: rootPath) else { throw CruzadorError.invalid("O teste exige uma pasta nova e absoluta.") }
        let runtime = try WineRuntime(root: URL(fileURLWithPath: runtimePath))
        let store = LibraryStore(root: URL(fileURLWithPath: rootPath)); try store.prepare()
        let lifecycle = BottleLifecycle(store: store)
        let bottle = try lifecycle.create(name: "Motor próprio", engine: Engine(kind: .packagedWine, path: runtime.root.path))
        let runner = CommandRunner()
        let trace = NativeSmokeTrace(root: store.root)
        try trace.recordRuntime(runtime)
        try trace.phase("initialize")
        let created = try await lifecycle.prepare(id: bottle.id, mode: .initialize, runner: runner, log: store.logsRoot.appendingPathComponent("initialize.log"))
        XCTAssertEqual(created.exitCode, 0)
        XCTAssertEqual(try store.load().bottles[0].state, .ready)
        try trace.phase("repair")
        let repaired = try await lifecycle.prepare(id: bottle.id, mode: .repair, runner: runner, log: store.logsRoot.appendingPathComponent("repair.log"))
        XCTAssertEqual(repaired.exitCode, 0)
        try trace.phase("reboot")
        let reg = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32/reg.exe")
        let scheduled = try await runner.run(EngineCommands.make(.run(LaunchRequest(path: reg.path, arguments: ["add", "HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce", "/v", "CruzadorReboot", "/t", "REG_SZ", "/d", "cmd.exe /c echo CRUZADOR_REBOOT_OK>C:\\cruzador-reboot.txt", "/f"])), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("reboot-schedule.log"))
        try scheduled.requireSuccess()
        let rebooted = try await lifecycle.prepare(id: bottle.id, mode: .reboot, runner: runner, log: store.logsRoot.appendingPathComponent("reboot.log"))
        try rebooted.requireSuccess()
        let rebootMarker = try String(contentsOf: store.prefix(for: bottle).appendingPathComponent("drive_c/cruzador-reboot.txt"), encoding: .utf8).contains("CRUZADOR_REBOOT_OK")
        XCTAssertTrue(rebootMarker)
        var observations: [[String: Any]] = []
        for (folder, marker) in [("system32", "CRUZADOR_WIN64_OK"), ("syswow64", "CRUZADOR_WIN32_OK")] {
            try trace.phase(folder)
            let executable = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/\(folder)/cmd.exe")
            let command = try EngineCommands.make(.run(LaunchRequest(path: executable.path, arguments: ["/c", "echo", marker, "%CRUZADOR_LAUNCH_VALUE%"], options: LaunchOptions(workingDirectory: store.prefix(for: bottle).appendingPathComponent("drive_c").path, environment: ["CRUZADOR_LAUNCH_VALUE": "OWN_ENV_OK"]))), bottle: bottle, store: store)
            let result = try await runner.run(command, log: store.logsRoot.appendingPathComponent("\(folder).log"))
            let text = try String(contentsOf: result.log, encoding: .utf8)
            XCTAssertEqual(result.exitCode, 0); XCTAssertTrue(text.contains(marker)); XCTAssertTrue(text.contains("OWN_ENV_OK"))
            observations.append(["pe_machine": "0x" + String(try WindowsPEHeader.inspect(executable), radix: 16), "executable": executable.path, "exit_code": result.exitCode, "marker": marker, "marker_observed": text.contains(marker), "explicit_environment_observed": text.contains("OWN_ENV_OK"), "log": result.log.path])
        }
        let cmd = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32/cmd.exe")
        try trace.phase("nonzero-exit")
        let failure = try await runner.run(EngineCommands.make(.run(LaunchRequest(path: cmd.path, arguments: ["/c", "exit", "7"])), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("exit7.log"))
        XCTAssertEqual(failure.exitCode, 7)
        try trace.phase("cancellation")
        let cancelID = UUID(), cancelLog = store.logsRoot.appendingPathComponent("cancel.log")
        let cancelPlan = try EngineCommands.make(.run(LaunchRequest(path: cmd.path, arguments: ["/c", "echo CRUZADOR_WAIT_READY && notepad.exe"])), bottle: bottle, store: store)
        let running = Task { try await runner.run(cancelPlan, log: cancelLog, operationID: cancelID) }
        var readyToCancel = false
        for _ in 0..<500 {
            if (try? String(contentsOf: cancelLog, encoding: .utf8))?.contains("CRUZADOR_WAIT_READY") == true { readyToCancel = true; break }
            try await Task.sleep(for: .milliseconds(20))
        }
        await runner.cancel(operationID: cancelID)
        let cancelled = try await running.value
        XCTAssertTrue(readyToCancel); XCTAssertTrue(cancelled.cancelled); XCTAssertTrue(cancelled.cleanupFailures.isEmpty)
        XCTAssertEqual(cancelled.phases.filter { $0.phase == "cancellation" }.compactMap(\.exitCode), [0, 0])
        try trace.phase("after-cancellation")
        let afterCancel = try await runner.run(EngineCommands.make(.run(LaunchRequest(path: cmd.path, arguments: ["/c", "echo", "CRUZADOR_AFTER_CANCEL"])), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("after-cancel.log"))
        try afterCancel.requireSuccess()
        XCTAssertTrue(try String(contentsOf: afterCancel.log, encoding: .utf8).contains("CRUZADOR_AFTER_CANCEL"))
        var positiveMSIExit: Int32?
        if let msi = ProcessInfo.processInfo.environment["CRUZADOR_TEST_MSI"] {
            try trace.phase("positive-msi")
            let request = try InstallationRequest(path: msi, mode: .quiet)
            let installed = try await InstallationService(store: store).run(request, bottle: try store.load().bottles[0], runner: runner, log: store.logsRoot.appendingPathComponent("positive-msi.log"))
            XCTAssertEqual(installed.exitCode, 0)
            XCTAssertEqual(try store.load().bottles[0].installations?.last?.status, .completed)
            let installedProgram = store.prefix(for: bottle).appendingPathComponent("drive_c/Program Files/7-Zip/7z.exe")
            XCTAssertTrue(FileManager.default.fileExists(atPath: installedProgram.path))
            let launched = try await runner.run(EngineCommands.make(.run(LaunchRequest(path: installedProgram.path)), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("installed-program.log"))
            try launched.requireSuccess()
            XCTAssertTrue(try String(contentsOf: launched.log, encoding: .utf8).contains("7-Zip"))
            positiveMSIExit = installed.exitCode
        }
        var recipeInstallationCount: Int?
        if let source = ProcessInfo.processInfo.environment["CRUZADOR_TEST_RECIPES"] {
            try trace.phase("recipe")
            let catalog = try RecipeCatalog(data: Data(contentsOf: URL(fileURLWithPath: source)))
            let service = RecipeInstallationService(store: store, runner: runner, cache: ArtifactCache(root: store.root.appendingPathComponent("Downloads")))
            let records = try await service.install(id: "7zip", bottleID: bottle.id, catalog: catalog)
            recipeInstallationCount = records.count
            let updated = try store.load().bottles[0]
            XCTAssertEqual(updated.installations?.last?.recipeID, "7zip")
            XCTAssertEqual(updated.installations?.last?.sourceSHA256, try catalog.artifact(for: catalog.recipes[0]).sha256)
            XCTAssertEqual(updated.apps.count, 2)
            let console = try XCTUnwrap(updated.apps.first(where: { $0.name == "7-Zip Console" }))
            let launched = try await runner.run(EngineCommands.make(.run(console.launchRequest), bottle: updated, store: store), log: store.logsRoot.appendingPathComponent("recipe-app.log"))
            try launched.requireSuccess()
            XCTAssertTrue(try String(contentsOf: launched.log, encoding: .utf8).contains("7-Zip"))
        }
        try trace.phase("negative-msi")
        let invalidMSI = store.root.appendingPathComponent("invalid-package.msi")
        try Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]).write(to: invalidMSI)
        let invalidRequest = try InstallationRequest(path: invalidMSI.path, mode: .quiet)
        do {
            _ = try await InstallationService(store: store).run(invalidRequest, bottle: try store.load().bottles[0], runner: runner, log: store.logsRoot.appendingPathComponent("invalid-msi.log"))
            XCTFail("An invalid MSI must not be successful")
        } catch CommandRunnerError.failed {}
        let installation = try XCTUnwrap(try store.load().bottles[0].installations?.last)
        let invalidMSIExit = try XCTUnwrap(installation.macOSExitCode)
        XCTAssertEqual(installation.status, .unconfirmed); XCTAssertNotEqual(invalidMSIExit, 0)
        try trace.phase("server-wait")
        let stopped = try await runner.run(Command(executable: runtime.server, arguments: ["-w"], environment: ["WINEPREFIX": store.prefix(for: bottle).path]), log: store.logsRoot.appendingPathComponent("server-wait.log"))
        XCTAssertEqual(stopped.exitCode, 0)
        #if arch(arm64)
        let hostArchitecture = "arm64"
        #elseif arch(x86_64)
        let hostArchitecture = "x86_64"
        #else
        let hostArchitecture = "unknown"
        #endif
        try trace.phase("discovery")
        let discovery = try AppDiscovery(store: store).scan(try store.load().bottles[0])
        if positiveMSIExit != nil || recipeInstallationCount != nil {
            XCTAssertTrue(discovery.registeredSoftware.contains { $0.name?.contains("7-Zip") == true })
            XCTAssertTrue(discovery.executables.contains { $0.inspection.path.hasSuffix("/7z.exe") })
        }
        if positiveMSIExit != nil || recipeInstallationCount != nil {
            let console = try XCTUnwrap(discovery.executables.first { $0.inspection.path.hasSuffix("/7z.exe") })
            try AppDiscovery(store: store).add(ids: [console.id], from: discovery)
        }
        try JSONEncoder().encode(discovery).write(to: store.root.appendingPathComponent("discovery.json"), options: .atomic)
        let libraryWorkflows = try await NativeLibraryWorkflowScenario(store: store, runner: runner).run(bottleID: bottle.id)
        var additionalApps: [[String: Any]]?
        if let assets = ProcessInfo.processInfo.environment["CRUZADOR_TEST_APPS"] {
            additionalApps = try await AdditionalWindowsAppsScenario(store: store, runner: runner).run(bottle: try store.load().bottles[0], assets: URL(fileURLWithPath: assets), lockURL: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("config/additional-validation-apps.json"))
        }
        try trace.phase("completed")
        var report: [String: Any] = ["formatVersion": 2, "root": store.root.path, "library_workflows": libraryWorkflows, "discovered_software_records": discovery.registeredSoftware.count, "discovered_executables": discovery.executables.count, "runtime": runtime.root.path, "version": runtime.manifest.version, "test_process_architecture": hostArchitecture,
                                    "operating_system": ProcessInfo.processInfo.operatingSystemVersionString, "initialization_exit": created.exitCode, "repair_exit": repaired.exitCode, "reboot_exit": rebooted.exitCode, "reboot_run_once_observed": rebootMarker,
                                    "windows_commands": observations, "nonzero_exit": failure.exitCode, "server_wait_exit": stopped.exitCode, "cancelled": cancelled.cancelled, "cancellation_cleanup_codes": cancelled.phases.filter { $0.phase == "cancellation" }.compactMap(\.exitCode), "after_cancellation_exit": afterCancel.exitCode, "invalid_msi_status": installation.status.rawValue, "invalid_msi_macOS_exit": invalidMSIExit,
                                    "limitations": ["No CrossOver executable is selected by these commands.", "No general application or graphics compatibility established."]]
        if let additionalApps { report["additional_apps"] = additionalApps }
        if let positiveMSIExit { report["positive_7zip_msi_exit"] = positiveMSIExit }
        if let recipeInstallationCount { report["recipe_installation_count"] = recipeInstallationCount; report["recipe_verified_shortcuts"] = 2 }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: store.root.appendingPathComponent("runtime-smoke.json"), options: .atomic)
    }
}
