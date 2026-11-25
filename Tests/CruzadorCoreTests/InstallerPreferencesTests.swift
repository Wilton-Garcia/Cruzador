import XCTest
@testable import CruzadorCore

final class InstallerPreferencesTests: XCTestCase {
    func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }; return root
    }
    func testPreferencesDefaultBackupInvalidRecoveryAndIdempotence() throws {
        let library = LibraryStore(root: try root()), store = InstallerPreferencesStore(library: library)
        XCTAssertEqual(try store.load().defaultMSIMode, .interactive)
        var selected = InstallerPreferences(); selected.defaultMSIMode = .quiet; selected.downloadPolicy = .cachedOnly; selected.cacheDirectory = library.root.appendingPathComponent("cache with spaces").path
        try store.save(selected); XCTAssertEqual(try store.load(), selected)
        let before = try Data(contentsOf: store.file); try store.save(selected)
        XCTAssertEqual(try Data(contentsOf: store.file), before)
        XCTAssertFalse(FileManager.default.fileExists(atPath: library.root.appendingPathComponent("Backups").path))
        var future = try XCTUnwrap(JSONSerialization.jsonObject(with: before) as? [String: Any]); future["formatVersion"] = 999
        let invalid = try JSONSerialization.data(withJSONObject: future); try invalid.write(to: store.file)
        XCTAssertThrowsError(try store.load())
        try store.save(selected)
        let backups = try FileManager.default.contentsOfDirectory(at: library.root.appendingPathComponent("Backups"), includingPropertiesForKeys: nil)
        XCTAssertEqual(backups.count, 1); XCTAssertEqual(try Data(contentsOf: backups[0]), invalid)
        selected.cacheDirectory = "relative/cache"; XCTAssertThrowsError(try store.save(selected))
        XCTAssertEqual(try store.load().defaultMSIMode, .quiet)
    }
    func testCachedOnlyNeverDownloadsAndStillRejectsChangedPayload() async throws {
        let directory = try root(), data = Data("pinned installer".utf8)
        let sample = directory.appendingPathComponent("sample"); try data.write(to: sample)
        let digest = try ArtifactCache.sha256(of: sample)
        let json: [String: Any] = ["id":"offline", "filename":"setup.exe", "url":"https://example.invalid/no-download.exe", "sha256":digest, "size":data.count, "upstream":"https://example.invalid", "release":"https://example.invalid/release"]
        let asset = try JSONDecoder().decode(InstallerArtifact.self, from: JSONSerialization.data(withJSONObject: json))
        let cache = ArtifactCache(root: directory.appendingPathComponent("selected"), downloadPolicy: .cachedOnly)
        do { _ = try await cache.fetch(asset); XCTFail("Cold offline cache must fail locally") }
        catch CruzadorError.invalid(let reason) { XCTAssertTrue(reason.contains("ausente do cache")) }
        let cached = await cache.cachedPath(for: asset)
        try FileManager.default.createDirectory(at: cached.deletingLastPathComponent(), withIntermediateDirectories: true); try data.write(to: cached)
        let warmed = try await cache.fetch(asset); XCTAssertEqual(warmed, cached)
        try Data("changed".utf8).write(to: cached)
        do { _ = try await cache.fetch(asset); XCTFail("Corrupt cache must not be used") } catch CruzadorError.invalid {}
        XCTAssertEqual(try Data(contentsOf: cached), Data("changed".utf8))
    }
    func testCacheOwnershipSurvivesModifiedPayloadAndFailedTrashPreservesReceipt() throws {
        let root = try root(), digest = String(repeating: "a", count: 64)
        let directory = root.appendingPathComponent(digest); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("setup.exe"), receipt = file.appendingPathExtension("receipt.json")
        try Data("modified owned data".utf8).write(to: file)
        try JSONEncoder().encode(ArtifactReceipt(sourceURL: URL(string: "https://example.invalid/setup.exe")!, sha256: digest, size: 100, downloadedAt: Date())).write(to: receipt)
        let unknown = directory.appendingPathComponent("notes.txt"); try Data("keep".utf8).write(to: unknown)
        let inventory = try InstallerCacheInventory.scan(root: root)
        XCTAssertEqual(inventory.entries.count, 1); XCTAssertEqual(inventory.ownedPaths.count, 2); XCTAssertEqual(inventory.unrecognized.map { $0.resolvingSymlinksInPath() }, [unknown.resolvingSymlinksInPath()])
        let failed = try InstallerCacheCleaner.clear(root: root) { _ in throw CruzadorError.invalid("fixture permission denied") }
        XCTAssertTrue(failed.moves.isEmpty); XCTAssertEqual(failed.errors.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: receipt.path))
        let trash = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true); addTeardownBlock { try? FileManager.default.removeItem(at: trash) }
        let result = try InstallerCacheCleaner.clear(root: root) { source in
            let target = trash.appendingPathComponent(source.lastPathComponent); try FileManager.default.moveItem(at: source, to: target); return target
        }
        XCTAssertEqual(result.moves.count, 2); XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unknown.path)); XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(try InstallerCacheInventory.scan(root: root).entries.isEmpty)
    }
    func testMalformedReceiptsAreNotOwnershipAndUnreadableShapeIsNotEmptyCache() throws {
        let root = try root(), directory = root.appendingPathComponent(String(repeating: "b", count: 64))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let receipt = directory.appendingPathComponent("app.exe.receipt.json"); try Data("invalid".utf8).write(to: receipt)
        let scanned = try InstallerCacheInventory.scan(root: root); XCTAssertTrue(scanned.entries.isEmpty); XCTAssertEqual(scanned.unrecognized.map { $0.resolvingSymlinksInPath() }, [receipt.resolvingSymlinksInPath()])
        let file = root.appendingPathComponent("not-a-folder"); try Data().write(to: file)
        XCTAssertThrowsError(try InstallerCacheInventory.scan(root: file))
    }
}

extension InstallerPreferencesTests {
    func testMixedCacheCleanupRetainsFailedReceiptsWhileMovingOtherEntries() throws {
        let cache = try root(), trash = try root()
        var paths: [String: URL] = [:]
        for (name, letter) in [("bad.exe", "d"), ("good.exe", "e")] {
            let digest = String(repeating: letter, count: 64), folder = cache.appendingPathComponent(String(repeating: letter, count: 64))
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent(name); try Data("owned".utf8).write(to: file)
            try JSONEncoder().encode(ArtifactReceipt(sourceURL: URL(string: "https://example.invalid/" + name)!, sha256: digest, size: 5, downloadedAt: Date())).write(to: file.appendingPathExtension("receipt.json"))
            paths[name] = file
        }
        let result = try InstallerCacheCleaner.clear(root: cache) { file in
            if file.lastPathComponent == "bad.exe" { throw CruzadorError.invalid("fixture locked payload") }
            let target = trash.appendingPathComponent(file.lastPathComponent); try FileManager.default.moveItem(at: file, to: target); return target
        }
        XCTAssertEqual(result.errors.count, 1); XCTAssertEqual(result.moves.count, 2)
        let failed = try XCTUnwrap(paths["bad.exe"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: failed.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: failed.appendingPathExtension("receipt.json").path))
        XCTAssertEqual(try InstallerCacheInventory.scan(root: cache).entries.count, 1)
    }
    func testSystemTrashForExplicitDisposableCacheRoot() throws {
        guard let rootPath = ProcessInfo.processInfo.environment["CRUZADOR_CACHE_TRASH_ROOT"], let reportPath = ProcessInfo.processInfo.environment["CRUZADOR_CACHE_TRASH_REPORT"] else { throw XCTSkip("Opt-in: move apenas dados novos descartáveis para a Lixeira real do macOS.") }
        guard rootPath.hasPrefix("/"), reportPath.hasPrefix("/"), !FileManager.default.fileExists(atPath: rootPath), !FileManager.default.fileExists(atPath: reportPath) else { throw CruzadorError.invalid("O teste exige pasta e relatório absolutos que ainda não existam.") }
        let cache = URL(fileURLWithPath: rootPath), digest = String(repeating: "f", count: 64)
        let folder = cache.appendingPathComponent(digest); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("Cruzador-cache-validation-\(UUID()).exe")
        let receipt = file.appendingPathExtension("receipt.json")
        try Data("disposable cache validation".utf8).write(to: file)
        try JSONEncoder().encode(ArtifactReceipt(sourceURL: URL(string: "https://example.invalid/disposable-validation")!, sha256: digest, size: 27, downloadedAt: Date())).write(to: receipt)
        let unrelated = cache.appendingPathComponent("preserved-control.txt"); try Data("keep".utf8).write(to: unrelated)
        let result = try InstallerCacheCleaner.clear(root: cache)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(to: URL(fileURLWithPath: reportPath), options: .withoutOverwriting)
        XCTAssertTrue(result.errors.isEmpty); XCTAssertEqual(result.moves.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path)); XCTAssertFalse(FileManager.default.fileExists(atPath: receipt.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }
}

extension InstallerPreferencesTests {
    func testUnavailablePayloadIsNotMissingAndItsReceiptCannotBeDiscarded() throws {
        let cache = try root(), digest = String(repeating: "9", count: 64)
        let folder = cache.appendingPathComponent(digest), payload = folder.appendingPathComponent("changed.exe")
        try FileManager.default.createDirectory(at: payload, withIntermediateDirectories: true)
        let receipt = payload.appendingPathExtension("receipt.json")
        try JSONEncoder().encode(ArtifactReceipt(sourceURL: URL(string: "https://example.invalid/changed.exe")!, sha256: digest, size: 1, downloadedAt: Date())).write(to: receipt)
        let inventory = try InstallerCacheInventory.scan(root: cache)
        XCTAssertEqual(inventory.missingCount, 0); XCTAssertEqual(inventory.unavailableCount, 1)
        let result = try InstallerCacheCleaner.clear(root: cache) { _ in XCTFail("Unavailable payload receipt must be retained"); return nil }
        XCTAssertTrue(result.moves.isEmpty); XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: receipt.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: payload.path))
    }
}
