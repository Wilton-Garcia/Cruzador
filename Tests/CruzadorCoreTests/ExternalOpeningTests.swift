import XCTest
@testable import CruzadorCore

final class ExternalOpeningTests: XCTestCase {
    func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func testShortcutAndLinkResolveCurrentLibraryWithoutEmbeddedCommands() throws {
        let root = try root()
        var bottle = Bottle(name: "日本語", engine: Engine(kind: .wine, path: "/bin/sh"))
        let app = WindowsApp(name: "App", path: root.appendingPathComponent("first.exe").path, arguments: ["a b"])
        bottle.apps = [app]
        var library = Library(); library.bottles = [bottle]
        let reference = LauncherReference(bottleID: bottle.id, appID: app.id)
        let file = root.appendingPathComponent("Meu atalho 日本語.cruzadorapp")
        try reference.write(to: file)
        XCTAssertEqual(try ExternalOpenTarget.parse(file), .launcher(reference))
        XCTAssertEqual(try ExternalOpenTarget.parse(reference.link), .launcher(reference))
        library.bottles[0].apps[0].path = root.appendingPathComponent("changed.exe").path
        XCTAssertEqual(try reference.resolve(in: library).app.path, library.bottles[0].apps[0].path)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(Set(encoded.keys), ["formatVersion", "bottleID", "appID"])
        library.bottles[0].apps = []
        XCTAssertThrowsError(try reference.resolve(in: library))
    }
    func testMalformedLinksUnknownFormatsAndMissingFilesAreRejected() throws {
        let root = try root(), reference = LauncherReference(bottleID: UUID(), appID: UUID())
        for text in [reference.link.absoluteString + "?command=cmd", reference.link.absoluteString + "#extra", reference.link.absoluteString + "/", "cruzador://user@launch/\(reference.bottleID)/\(reference.appID)", "cruzador://launch:80/\(reference.bottleID)/\(reference.appID)", "https://launch/\(reference.bottleID)/\(reference.appID)", "cruzador://launch/../cmd", "cruzador://launch/\(reference.bottleID)//\(reference.appID)"] {
            XCTAssertThrowsError(try ExternalOpenTarget.parse(XCTUnwrap(URL(string: text))), text)
        }
        let file = root.appendingPathComponent("future.cruzadorapp")
        try Data("{\"formatVersion\":2,\"bottleID\":\"\(reference.bottleID)\",\"appID\":\"\(reference.appID)\"}".utf8).write(to: file)
        XCTAssertThrowsError(try ExternalOpenTarget.parse(file))
        try Data("{}".utf8).write(to: file)
        XCTAssertThrowsError(try ExternalOpenTarget.parse(file))
        XCTAssertThrowsError(try ExternalOpenTarget.parse(root.appendingPathComponent("missing.cruzadorapp")))
        XCTAssertThrowsError(try ExternalOpenTarget.parse(root.appendingPathComponent("other.txt")))
    }
    func testWindowsFilesAndTransferPackagesHaveDistinctRoutes() throws {
        let root = try root(), exe = root.appendingPathComponent("App.EXE"), msi = root.appendingPathComponent("Setup.msi")
        XCTAssertEqual(try ExternalOpenTarget.parse(exe), .windowsFile(exe))
        XCTAssertEqual(try ExternalOpenTarget.parse(msi), .windowsFile(msi))
        // Routing a Windows file does not attest its validity; the installation/execution boundary inspects it.
        XCTAssertThrowsError(try WindowsFileInspection.inspect(path: exe.path))
        let package = root.appendingPathComponent("Backup.cruzadorbottle")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        XCTAssertEqual(try ExternalOpenTarget.parse(package), .bottlePackage(package))
        try FileManager.default.removeItem(at: package); try Data().write(to: package)
        XCTAssertThrowsError(try ExternalOpenTarget.parse(package))
    }
}
