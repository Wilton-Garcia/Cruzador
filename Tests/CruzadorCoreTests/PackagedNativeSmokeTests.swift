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
        let created = try await lifecycle.prepare(id: bottle.id, mode: .initialize, runner: runner, log: store.logsRoot.appendingPathComponent("initialize.log"))
        XCTAssertEqual(created.exitCode, 0)
        XCTAssertEqual(try store.load().bottles[0].state, .ready)
        let repaired = try await lifecycle.prepare(id: bottle.id, mode: .repair, runner: runner, log: store.logsRoot.appendingPathComponent("repair.log"))
        XCTAssertEqual(repaired.exitCode, 0)
        var observations: [[String: Any]] = []
        for (folder, marker) in [("system32", "CRUZADOR_WIN64_OK"), ("syswow64", "CRUZADOR_WIN32_OK")] {
            let executable = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/\(folder)/cmd.exe")
            let command = try EngineCommands.make(.run(LaunchRequest(path: executable.path, arguments: ["/c", "echo", marker, "%CRUZADOR_LAUNCH_VALUE%"], options: LaunchOptions(workingDirectory: store.prefix(for: bottle).appendingPathComponent("drive_c").path, environment: ["CRUZADOR_LAUNCH_VALUE": "OWN_ENV_OK"]))), bottle: bottle, store: store)
            let result = try await runner.run(command, log: store.logsRoot.appendingPathComponent("\(folder).log"))
            let text = try String(contentsOf: result.log, encoding: .utf8)
            XCTAssertEqual(result.exitCode, 0); XCTAssertTrue(text.contains(marker)); XCTAssertTrue(text.contains("OWN_ENV_OK"))
            observations.append(["executable": executable.path, "exit_code": result.exitCode, "marker": marker, "marker_observed": text.contains(marker), "explicit_environment_observed": text.contains("OWN_ENV_OK"), "log": result.log.path])
        }
        let cmd = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32/cmd.exe")
        let failure = try await runner.run(EngineCommands.make(.run(LaunchRequest(path: cmd.path, arguments: ["/c", "exit", "7"])), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("exit7.log"))
        XCTAssertEqual(failure.exitCode, 7)
        let stopped = try await runner.run(Command(executable: runtime.server, arguments: ["-w"], environment: ["WINEPREFIX": store.prefix(for: bottle).path]), log: store.logsRoot.appendingPathComponent("server-wait.log"))
        XCTAssertEqual(stopped.exitCode, 0)
        #if arch(arm64)
        let hostArchitecture = "arm64"
        #elseif arch(x86_64)
        let hostArchitecture = "x86_64"
        #else
        let hostArchitecture = "unknown"
        #endif
        let report: [String: Any] = ["runtime": runtime.root.path, "version": runtime.manifest.version, "test_process_architecture": hostArchitecture,
                                    "operating_system": ProcessInfo.processInfo.operatingSystemVersionString, "initialization_exit": created.exitCode, "repair_exit": repaired.exitCode,
                                    "windows_commands": observations, "nonzero_exit": failure.exitCode, "server_wait_exit": stopped.exitCode,
                                    "limitations": ["No CrossOver executable is selected by these commands.", "No general application or graphics compatibility established."]]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: store.root.appendingPathComponent("runtime-smoke.json"), options: .atomic)
    }
}
