import XCTest
@testable import CruzadorCore

final class NativeControlMetadataTests: XCTestCase {
    func testRetainedControlMetadataUsesTheSelectedServerRatherThanItsDefaultName() throws {
        let root = try makeSynchronizationPackage()
        let server = root.appendingPathComponent("helpers/custom-server")
        try FileManager.default.createDirectory(at: server.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: root.appendingPathComponent("bin/wineserver"), to: server)
        let manifest = root.appendingPathComponent("runtime.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        object["serverExecutable"] = "helpers/custom-server"
        try JSONSerialization.data(withJSONObject: object).write(to: manifest)
        let runtime = try WineRuntime(root: root), store = LibraryStore(root: root.appendingPathComponent("data"))
        try store.prepare()
        let bottle = Bottle(name: "Control metadata", engine: Engine(kind: .packagedWine, path: root.path))
        let plan = try EngineCommands.make(.initialize, bottle: bottle, store: store)
        try NativeSmokeTrace(root: store.root).recordRuntime(runtime)
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: store.root.appendingPathComponent("runtime-control.json"))) as? [String: Any])
        XCTAssertEqual(record["runtime"] as? String, runtime.root.path)
        XCTAssertEqual(record["wine"] as? String, plan.primary.executable.path)
        XCTAssertEqual(record["server"] as? String, plan.cancellation.first?.executable.path)
        XCTAssertEqual(record["server"] as? String, server.resolvingSymlinksInPath().path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("bin/wineserver").path))
    }
}
