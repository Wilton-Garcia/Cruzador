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
    func testPlatformMetadataCannotBeSilentlyIgnored() throws {
        let root = try fixture(), file = root.appendingPathComponent("runtime.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        object["features"] = ["msync"]
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        XCTAssertThrowsError(try WineRuntime(root: root))
        object["formatVersion"] = 2
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        XCTAssertThrowsError(try WineRuntime(root: root))
        object["minimumMacOSVersion"] = ["major": 999, "minor": 0, "patch": 0]
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        XCTAssertThrowsError(try WineRuntime(root: root))
        object["minimumMacOSVersion"] = ["major": 14, "minor": 0, "patch": 0]
        try JSONSerialization.data(withJSONObject: object).write(to: file)
        XCTAssertEqual(try WineRuntime(root: root).manifest.features, ["msync"])
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
        XCTAssertNil(command.primary.environment["CX_BOTTLE"])
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
    func testInitializationFinalizesRegistryBeforeReadinessCheck() async throws {
        let root = try fixture()
        let primary = #"""
        #!/bin/sh
        mkdir -p "$WINEPREFIX/drive_c"
        printf pending > "$WINEPREFIX/pending"
        """#
        let finalizer = #"""
        #!/bin/sh
        test -f "$WINEPREFIX/pending" || exit 3
        printf registry > "$WINEPREFIX/system.reg"
        """#
        try (primary + "\n").write(to: root.appendingPathComponent("bin/wine"), atomically: true, encoding: .utf8)
        try (finalizer + "\n").write(to: root.appendingPathComponent("bin/wineserver"), atomically: true, encoding: .utf8)
        for name in ["wine", "wineserver"] { try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.appendingPathComponent("bin/\(name)").path) }
        let store = LibraryStore(root: root.appendingPathComponent("data"))
        let bottle = Bottle(name: "A", engine: Engine(kind: .packagedWine, path: root.path))
        let result = try await CommandRunner().run(EngineCommands.make(.initialize, bottle: bottle, store: store), log: root.appendingPathComponent("init.log"))
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(store.isInitialized(bottle))
    }

    func testFinalizationFailureIsNotSuccessfulInitialization() async throws {
        let root = try fixture()
        let log = root.appendingPathComponent("phases.log")
        let primary = Command(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf primary; exit 0"], environment: [:])
        let finalizer = Command(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf finalizer; exit 9"], environment: [:])
        let result = try await CommandRunner().run(EnginePlan(primary: primary, finalization: [finalizer]), log: log)
        XCTAssertEqual(result.exitCode, 9)
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "primaryfinalizer")
        let failedPrimary = Command(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf failed; exit 7"], environment: [:])
        let failed = try await CommandRunner().run(EnginePlan(primary: failedPrimary, finalization: [finalizer]), log: log)
        XCTAssertEqual(failed.exitCode, 7)
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "failedfinalizer")
    }

}
