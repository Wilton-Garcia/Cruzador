import XCTest
@testable import CruzadorCore

final class CoreTests: XCTestCase {
    func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func executable(_ path: URL, text: String = "#!/bin/sh\nexit 0\n") throws {
        try text.write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
    }
    func testMetadataRoundTripAndBackupPreserveNames() throws {
        let store = LibraryStore(root: try temporary()); var library = Library()
        let bottle = Bottle(name: "../ Jogos 日本語", engine: Engine(kind: .crossOver, path: "/Applications/CrossOver.app"))
        library.bottles = [bottle]; try store.save(library)
        XCTAssertEqual(try store.load().bottles, [bottle])
        XCTAssertEqual(store.prefix(for: bottle).lastPathComponent, bottle.id.uuidString)
        library.bottles[0].name = "Novo nome"; try store.save(library)
        let previous = try JSONDecoder().decode(Library.self, from: Data(contentsOf: store.root.appendingPathComponent("library.json.bak")))
        XCTAssertEqual(previous.bottles[0].name, bottle.name)
    }
    func testMalformedLibraryIsNeverOverwritten() throws {
        let store = LibraryStore(root: try temporary())
        let original = Data("{broken".utf8); try original.write(to: store.manifest)
        XCTAssertThrowsError(try store.load()); XCTAssertThrowsError(try store.save(Library()))
        XCTAssertEqual(try Data(contentsOf: store.manifest), original)
    }
    func testCrossOverRoutesOnlyToOwnedUUIDAndKeepsArguments() throws {
        let root = try temporary(); let store = LibraryStore(root: root.appendingPathComponent("data"))
        let base = root.appendingPathComponent("Cross Over.app/Contents/SharedSupport/CrossOver/bin")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try executable(base.appendingPathComponent("wine")); try executable(base.appendingPathComponent("cxbottle"))
        let engine = Engine(kind: .crossOver, path: root.appendingPathComponent("Cross Over.app").path)
        let bottle = Bottle(name: "Meu jogo", engine: engine)
        let program = root.appendingPathComponent("a ; $(touch nope).exe"); try Data().write(to: program)
        let run = try EngineCommands.make(.run(program.path, ["two words", "--flag"]), bottle: bottle, store: store)
        XCTAssertEqual(Array(run.primary.arguments.suffix(4)), ["--", program.path, "two words", "--flag"])
        XCTAssertEqual(run.primary.environment["CX_BOTTLE_PATH"], store.bottlesRoot.path)
        XCTAssertEqual(run.primary.environment["WINEPREFIX"], store.prefix(for: bottle).path)
        let create = try EngineCommands.make(.initialize, bottle: bottle, store: store)
        XCTAssertTrue(create.primary.arguments.contains("win10_64"))
        XCTAssertFalse(store.isInitialized(bottle))
        try FileManager.default.createDirectory(at: store.prefix(for: bottle).appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        XCTAssertFalse(store.isInitialized(bottle))
        try Data().write(to: store.prefix(for: bottle).appendingPathComponent("system.reg"))
        XCTAssertTrue(store.isInitialized(bottle))
    }
    func testMissingEngineAndUnknownToolAreActionableFailures() throws {
        let store = LibraryStore(root: try temporary())
        let bottle = Bottle(name: "A", engine: Engine(kind: .wine, path: "/no/such/wine"))
        XCTAssertThrowsError(try EngineCommands.make(.initialize, bottle: bottle, store: store))
        XCTAssertThrowsError(try EngineCommands.make(.tool("unexpected"), bottle: bottle, store: store))
    }
    func testMSIUsesMsiexec() throws {
        let root = try temporary(); let wine = root.appendingPathComponent("wine"); try executable(wine)
        let msi = root.appendingPathComponent("Setup with spaces.msi"); try Data().write(to: msi)
        let bottle = Bottle(name: "A", engine: Engine(kind: .wine, path: wine.path))
        let command = try EngineCommands.make(.install(msi.path), bottle: bottle, store: LibraryStore(root: root))
        XCTAssertEqual(command.primary.arguments, ["msiexec", "/i", msi.path])
    }
    func testRunnerKeepsExitAndDoesNotInterpretShellArguments() async throws {
        let root = try temporary(); let script = root.appendingPathComponent("engine")
        try executable(script, text: "#!/bin/sh\nprintf '%s\\n' \"$WINEPREFIX\" \"$1\"\nexit 7\n")
        let log = root.appendingPathComponent("run.log")
        let command = Command(executable: script, arguments: ["$(touch sentinel); a b"], environment: ["WINEPREFIX": "/selected prefix"])
        let result = try await CommandRunner().run(command, log: log)
        XCTAssertEqual(result.exitCode, 7)
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "/selected prefix\n$(touch sentinel); a b\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("sentinel").path))
    }
}
