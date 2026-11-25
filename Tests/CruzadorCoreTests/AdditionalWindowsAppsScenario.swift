import XCTest
@testable import CruzadorCore

/// Offline application behavior through the same command plans used by the UI.
struct AdditionalWindowsAppsScenario {
    struct Lock: Decodable { let formatVersion: Int; let assets: [Asset] }
    struct Asset: Decodable { let id: String; let filename: String; let sha256: String; let member: String?; let member_sha256: String? }
    let store: LibraryStore
    let runner: CommandRunner
    func run(bottle: Bottle, assets: URL, lockURL: URL) async throws -> [[String: Any]] {
        let lock = try JSONDecoder().decode(Lock.self, from: Data(contentsOf: lockURL))
        guard lock.formatVersion == 1 else { throw CruzadorError.invalid("Formato dos aplicativos de teste desconhecido.") }
        var observations: [[String: Any]] = []
        for asset in lock.assets {
            let filename = asset.member ?? asset.filename
            guard URL(fileURLWithPath: filename).lastPathComponent == filename else { throw CruzadorError.invalid("Nome de artefato inválido.") }
            let executable = assets.appendingPathComponent(filename)
            let expected = asset.member_sha256 ?? asset.sha256
            guard try ArtifactCache.sha256(of: executable) == expected else { throw CruzadorError.invalid("Aplicativo de teste difere do hash fixado.") }
            let machine = try WindowsPEHeader.inspect(executable)
            XCTAssertEqual(machine, asset.id == "plink-w32" ? 0x14c : 0x8664)
            let database = "C:\\cruzador-compatibility.db"
            let cases: [(String, [String], String)] = asset.id.hasPrefix("plink")
                ? [("version", ["-V"], "Release 0.85")]
                : [("write", [database, "CREATE TABLE sample(value TEXT); INSERT INTO sample VALUES('CRUZADOR_SQLITE_OK'); SELECT value FROM sample;"], "CRUZADOR_SQLITE_OK"),
                   ("read", [database, "PRAGMA integrity_check; SELECT value FROM sample;"], "CRUZADOR_SQLITE_OK")]
            for (name, arguments, marker) in cases {
                try NativeSmokeTrace(root: store.root).phase(asset.id + "-" + name)
                let result = try await runner.run(EngineCommands.make(.run(LaunchRequest(path: executable.path, arguments: arguments)), bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent(asset.id + "-" + name + ".log"))
                try result.requireSuccess()
                let text = try String(contentsOf: result.log, encoding: .utf8)
                XCTAssertTrue(text.contains(marker))
                if name == "read" { XCTAssertTrue(text.components(separatedBy: .newlines).contains("ok")) }
                observations.append(["id": asset.id, "case": name, "executable": executable.path, "sha256": expected, "pe_machine": "0x" + String(machine, radix: 16), "arguments": arguments, "exit": result.exitCode, "cancelled": result.cancelled, "marker_observed": text.contains(marker), "integrity_ok": name == "read" && text.components(separatedBy: .newlines).contains("ok"), "log": result.log.path, "log_sha256": try ArtifactCache.sha256(of: result.log)])
            }
        }
        let idle = try await runner.run(EngineCommands.make(.waitForIdle, bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("additional-apps-wait.log"))
        try idle.requireSuccess()
        return observations
    }
}
