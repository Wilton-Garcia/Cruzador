import XCTest
@testable import CruzadorCore

final class WineRuntimeTests: XCTestCase {
    func fixture(winePath: String = "bin/wine") throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("bin"), withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        for name in ["wine", "wineserver"] {
            let path = root.appendingPathComponent("bin/\(name)")
            try "#!/bin/sh\nprintf '%s\\n' \"$WINESERVER\" \"$WINEPREFIX\" \"$1\"\n".write(to: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
        }
        try "Fixture only; not a Wine distribution".write(to: root.appendingPathComponent("LICENSE"), atomically: true, encoding: .utf8)
        let manifest = WineRuntimeManifest(version: "fixture", sourceURL: "https://example.invalid/source", sourceRevision: "fixture", architectures: ["test"], wineExecutable: winePath, licenseFiles: ["LICENSE"])
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("runtime.json"))
        return root
    }
    func testPackagedEngineLaunchesWithItsOwnServerAndPrefix() async throws {
        let root = try fixture(); let store = LibraryStore(root: root.appendingPathComponent("data"))
        let bottle = Bottle(name: "Own engine", engine: Engine(kind: .packagedWine, path: root.path))
        let command = try EngineCommands.make(.initialize, bottle: bottle, store: store)
        let log = root.appendingPathComponent("run.log")
        let result = try await CommandRunner().run(command, log: log)
        XCTAssertEqual(result.exitCode, 0)
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertTrue(text.contains(root.appendingPathComponent("bin/wineserver").path))
        XCTAssertTrue(text.contains(store.prefix(for: bottle).path))
        XCTAssertTrue(text.contains("wineboot"))
        XCTAssertNil(command.environment["CX_BOTTLE"])
    }
    func testManifestCannotSelectAnExternalExecutable() throws {
        let root = try fixture(winePath: "../external/wine")
        XCTAssertThrowsError(try WineRuntime(root: root))
        let contained = try fixture()
        let wine = contained.appendingPathComponent("bin/wine")
        try FileManager.default.removeItem(at: wine)
        try FileManager.default.createSymbolicLink(at: wine, withDestinationURL: URL(fileURLWithPath: "/bin/sh"))
        XCTAssertThrowsError(try WineRuntime(root: contained))
    }
    func testMissingManifestAndComponentDoNotFallback() throws {
        let root = try fixture(); try FileManager.default.removeItem(at: root.appendingPathComponent("bin/wineserver"))
        let bottle = Bottle(name: "A", engine: Engine(kind: .packagedWine, path: root.path))
        XCTAssertThrowsError(try EngineCommands.make(.initialize, bottle: bottle, store: LibraryStore(root: root)))
        try FileManager.default.removeItem(at: root.appendingPathComponent("runtime.json"))
        XCTAssertThrowsError(try WineRuntime(root: root))
    }
}
