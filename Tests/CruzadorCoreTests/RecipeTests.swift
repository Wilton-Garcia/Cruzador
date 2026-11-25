import XCTest
@testable import CruzadorCore

final class RecipeTests: XCTestCase {
    func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    func payload(_ tag: UInt8) -> Data {
        var bytes = Data(repeating: 0, count: 71); bytes[0] = 0x4d; bytes[1] = 0x5a; bytes[0x3c] = 64
        bytes.replaceSubrange(64..<70, with: [0x50, 0x45, 0, 0, 0x64, 0x86]); bytes[70] = tag
        return bytes
    }
    func document(root: URL) throws -> [String: Any] {
        var assets: [[String: Any]] = []
        for (name, tag) in [("dep", UInt8(1)), ("app", UInt8(2))] {
            let source = root.appendingPathComponent(name + ".source"); try payload(tag).write(to: source)
            let hash = try ArtifactCache.sha256(of: source)
            let directory = root.appendingPathComponent("cache/\(hash)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try payload(tag).write(to: directory.appendingPathComponent(name + ".exe"))
            assets.append(["id": name, "filename": name + ".exe", "sha256": hash, "size": 71, "url": "https://example.invalid/\(name).exe", "upstream": "https://example.invalid/", "release": "https://example.invalid/release"])
        }
        let recipes: [[String: Any]] = [
            ["id": "app", "name": "App", "version": "1", "summary": "Fixture", "homepage": "https://example.invalid/", "dependencies": ["dep"], "installerArtifactID": "app", "mode": "interactive", "arguments": [], "shortcuts": [["name": "Application", "relativePath": "drive_c/app.exe", "arguments": []]]],
            ["id": "dep", "name": "Dependency", "version": "1", "summary": "Fixture", "homepage": "https://example.invalid/", "dependencies": [], "installerArtifactID": "dep", "mode": "interactive", "arguments": [], "shortcuts": []]
        ]
        return ["formatVersion": 1, "artifacts": assets, "recipes": recipes]
    }
    func testGraphOrderingMissingDependenciesAndCycles() throws {
        let root = try root(); var document = try document(root: root)
        let catalog = try RecipeCatalog(data: JSONSerialization.data(withJSONObject: document))
        XCTAssertEqual(try catalog.plan(for: "app").map(\.id), ["dep", "app"])
        var recipes = document["recipes"] as! [[String: Any]]
        recipes[1]["dependencies"] = ["app"]; document["recipes"] = recipes
        XCTAssertThrowsError(try RecipeCatalog(data: JSONSerialization.data(withJSONObject: document)))
        recipes[1]["dependencies"] = ["missing"]; document["recipes"] = recipes
        XCTAssertThrowsError(try RecipeCatalog(data: JSONSerialization.data(withJSONObject: document)))
    }
    func testDependencyExecutionAndShortcutsUseVerifiedCache() async throws {
        let root = try root(); let catalog = try RecipeCatalog(data: JSONSerialization.data(withJSONObject: document(root: root)))
        let store = LibraryStore(root: root.appendingPathComponent("library")), cache = ArtifactCache(root: root.appendingPathComponent("cache"))
        let wine = root.appendingPathComponent("wine")
        let script = #"""
        #!/bin/sh
        case "$1" in
          */dep.exe) printf dep >> "$WINEPREFIX/order" ;;
          */app.exe) test "$(cat "$WINEPREFIX/order")" = dep || test -f "$WINEPREFIX/drive_c/app.exe" || exit 4
                     printf app >> "$WINEPREFIX/order"
                     printf program > "$WINEPREFIX/drive_c/app.exe" ;;
        esac
        """#
        try (script + "\n").write(to: wine, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
        var bottle = Bottle(name: "Recipes", engine: Engine(kind: .wine, path: wine.path)); bottle.state = .ready
        try FileManager.default.createDirectory(at: store.prefix(for: bottle).appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        try Data().write(to: store.prefix(for: bottle).appendingPathComponent("system.reg"))
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        let service = RecipeInstallationService(store: store, runner: CommandRunner(), cache: cache)
        let installed = try await service.install(id: "app", bottleID: bottle.id, catalog: catalog)
        XCTAssertEqual(installed.count, 2)
        var saved = try store.load().bottles[0]
        XCTAssertEqual(saved.installations?.compactMap(\.recipeID), ["dep", "app"])
        XCTAssertEqual(saved.apps.count, 1)
        XCTAssertEqual(try String(contentsOf: store.prefix(for: bottle).appendingPathComponent("order"), encoding: .utf8), "depapp")
        _ = try await service.install(id: "app", bottleID: bottle.id, catalog: catalog)
        saved = try store.load().bottles[0]
        XCTAssertEqual(saved.apps.count, 1); XCTAssertEqual(saved.installations?.count, 4)
        try "#!/bin/sh\nexit 6\n".write(to: wine, atomically: true, encoding: .utf8)
        do { _ = try await service.install(id: "app", bottleID: bottle.id, catalog: catalog); XCTFail("Dependency failure must stop the recipe") } catch {}
        saved = try store.load().bottles[0]
        XCTAssertEqual(saved.installations?.count, 5)
        XCTAssertEqual(saved.installations?.last?.recipeID, "dep")
        XCTAssertEqual(saved.installations?.last?.status, .unconfirmed)
        let artifact = try catalog.artifact(for: catalog.recipes[0]); let path = await cache.cachedPath(for: artifact)
        let altered = Data(repeating: 1, count: 71); try altered.write(to: path)
        do { _ = try await cache.fetch(artifact); XCTFail("Altered cache must fail integrity verification") } catch {}
        XCTAssertEqual(try Data(contentsOf: path), altered)
    }
    func testBundledCatalogParsesPinnedRealArtifacts() throws {
        let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let catalog = try RecipeCatalog(data: Data(contentsOf: repository.appendingPathComponent("config/recipes.json")))
        XCTAssertEqual(try catalog.plan(for: "7zip").map(\.id), ["7zip"])
        XCTAssertEqual(try catalog.artifact(for: catalog.recipes[0]).size, 1659704)
    }
}
