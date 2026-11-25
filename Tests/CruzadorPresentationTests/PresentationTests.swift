import XCTest
import CruzadorCore
@testable import Cruzador

@MainActor
final class TestDocumentHistory: DocumentHistory {
    var urls: [URL] = []
    func note(_ url: URL) { urls.append(url) }
    func clear() { urls = [] }
}

@MainActor
final class PresentationTests: XCTestCase {
    func fixture() throws -> (AppModel, URL, Bottle) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "CruzadorPresentationTests.\(UUID())"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        let store = LibraryStore(root: root)
        let engine = Engine(kind: .wine, path: "/missing/test-wine")
        try EnginePreferences.save(engine, to: preferences)
        var bottle = Bottle(name: "Presentation", engine: engine); bottle.state = .ready
        var library = Library(); library.bottles = [bottle]; try store.save(library)
        let prefix = store.prefix(for: bottle)
        try FileManager.default.createDirectory(at: prefix.appendingPathComponent("drive_c"), withIntermediateDirectories: true)
        try Data("registry".utf8).write(to: prefix.appendingPathComponent("system.reg"))
        let exe = root.appendingPathComponent("Installer with spaces.exe")
        var bytes = Data(repeating: 0, count: 70); bytes[0] = 0x4d; bytes[1] = 0x5a; bytes[0x3c] = 64
        bytes.replaceSubrange(64..<70, with: [0x50, 0x45, 0, 0, 0x64, 0x86]); try bytes.write(to: exe)
        return (AppModel(store: store, preferences: preferences, documents: TestDocumentHistory()), exe, bottle)
    }
    func testExternalReviewTransitionsToInstallerWithoutBeingDismissedByPreviousRoute() throws {
        let (model, file, bottle) = try fixture()
        XCTAssertTrue(model.loaded); XCTAssertNil(model.presentation)
        model.receiveExternal([file])
        XCTAssertEqual(model.presentation, .incoming); XCTAssertEqual(model.incomingRequests.count, 1)
        model.acceptIncoming(bottleID: bottle.id, install: true)
        XCTAssertEqual(model.presentation, .installer)
        XCTAssertEqual(model.selectedInstaller?.path, file.path)
        XCTAssertTrue(model.incomingRequests.isEmpty); XCTAssertFalse(model.busy)
        XCTAssertEqual(model.recentDocuments, [file])
        model.dismissPresentation(.incoming)
        XCTAssertEqual(model.presentation, .installer)
        model.dismissPresentation(.installer); XCTAssertNil(model.presentation)
    }
    func testIncomingRequestsDoNotReplaceExistingDialogOrStartWhileBusy() throws {
        let (model, file, _) = try fixture()
        model.presentation = .create
        model.receiveExternal([file]); XCTAssertEqual(model.presentation, .create)
        model.dismissPresentation(.create)
        model.busy = true; model.reviewIncoming(); XCTAssertNil(model.presentation)
        model.receiveExternal([file]); XCTAssertEqual(model.incomingRequests.count, 2); XCTAssertNil(model.presentation)
        model.busy = false; model.reviewIncoming(); XCTAssertEqual(model.presentation, .incoming)
        model.discardIncoming(); XCTAssertNil(model.presentation); XCTAssertEqual(model.incomingRequests.count, 1)
        model.reviewIncoming(); XCTAssertEqual(model.presentation, .incoming)
    }
    func testReentrantAndLateEditorActionsDoNotReplaceOrSaveAnotherDialog() throws {
        let (model, file, _) = try fixture()
        var library = try model.store.load()
        let existing = WindowsApp(name: "Existing", path: file.path)
        library.bottles[0].apps = [existing]; try model.store.save(library); model.reload()
        model.beginRegister(existing)
        XCTAssertEqual(model.presentation, .register); XCTAssertEqual(model.editingApp?.id, existing.id)
        model.beginRegister()
        XCTAssertEqual(model.editingApp?.id, existing.id)
        model.dismissPresentation(.register)
        let before = try Data(contentsOf: model.store.manifest)
        model.register(name: "Late save", path: file.path, arguments: "", workingDirectory: "", environmentJSON: "{}")
        XCTAssertEqual(try Data(contentsOf: model.store.manifest), before)
        model.beginRegister(); XCTAssertNil(model.editingApp); XCTAssertEqual(model.presentation, .register)
    }
    func testMissingLauncherReferenceKeepsRequestForReview() throws {
        let (model, _, _) = try fixture()
        let reference = LauncherReference(bottleID: UUID(), appID: UUID())
        model.receiveExternal([reference.link])
        model.acceptIncoming(bottleID: nil, install: false)
        XCTAssertEqual(model.presentation, .incoming); XCTAssertEqual(model.incomingRequests.count, 1)
        XCTAssertNotNil(model.error); XCTAssertFalse(model.busy)
    }
}

@MainActor
final class LaunchFailureTests: XCTestCase {
    func testInvalidLaunchDoesNotTouchTheDefaultOrSelectedLibrary() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = AppModel(store: LibraryStore(root: root), startupError: "Invalid selected root")
        XCTAssertFalse(model.loaded); XCTAssertFalse(model.canStart); XCTAssertEqual(model.error, "Invalid selected root")
        model.reload(); XCTAssertFalse(model.loaded); XCTAssertFalse(model.canStart)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }
}
