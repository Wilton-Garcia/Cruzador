import XCTest
@testable import CruzadorCore

final class NativeSmokeTests: XCTestCase {
    /// Opt-in: executes the installed CrossOver in a new, retained test root.
    func testInstalledCrossOverCreatesBottleAndRunsWindowsCommand() async throws {
        guard let root = ProcessInfo.processInfo.environment["CRUZADOR_NATIVE_SMOKE_ROOT"] else {
            throw XCTSkip("Defina CRUZADOR_NATIVE_SMOKE_ROOT para testar o CrossOver real em uma pasta nova.")
        }
        guard root.hasPrefix("/"), !FileManager.default.fileExists(atPath: root) else {
            throw CruzadorError.invalid("O smoke test exige uma pasta absoluta que ainda não exista.")
        }
        let store = LibraryStore(root: URL(fileURLWithPath: root)); try store.prepare()
        var bottle = Bottle(name: "Cruzador smoke", engine: Engine(kind: .crossOver, path: "/Applications/CrossOver.app"))
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        let runner = CommandRunner()
        let create = try EngineCommands.make(.initialize, bottle: bottle, store: store)
        let result = try await runner.run(create, log: store.logsRoot.appendingPathComponent("create.log"))
        XCTAssertEqual(result.exitCode, 0)
        guard result.exitCode == 0, store.isInitialized(bottle) else {
            XCTFail("A bottle não foi inicializada; consulte create.log em \(root)"); return
        }
        bottle.state = .ready; library.bottles = [bottle]; try store.save(library)
        let cmd = store.prefix(for: bottle).appendingPathComponent("drive_c/windows/system32/cmd.exe")
        let run = try EngineCommands.make(.run(cmd.path, ["/c", "echo", "CRUZADOR_SMOKE_OK"]), bottle: bottle, store: store)
        let runResult = try await runner.run(run, log: store.logsRoot.appendingPathComponent("cmd.log"))
        XCTAssertEqual(runResult.exitCode, 0)
        XCTAssertTrue(try String(contentsOf: runResult.log, encoding: .utf8).contains("CRUZADOR_SMOKE_OK"))
        // Wait for the server of this explicitly isolated prefix to exit.
        let base = URL(fileURLWithPath: bottle.engine.path).appendingPathComponent("Contents/SharedSupport/CrossOver/bin/wine")
        let stop = Command(executable: base, arguments: ["--bottle", bottle.id.uuidString, "--scope", "private", "--no-gui", "--wait-all"], environment: create.primary.environment)
        let stopped = try await runner.run(stop, log: store.logsRoot.appendingPathComponent("shutdown.log"))
        XCTAssertEqual(stopped.exitCode, 0)
    }
}
