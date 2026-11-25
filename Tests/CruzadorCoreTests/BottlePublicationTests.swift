import XCTest
@testable import CruzadorCore

extension BottleMaintenanceTests {
    func testPublishedRevisionsAreVerifiedAndManagedUpdatesPreserveOldBottle() async throws {
        let (maintenance, bottle) = try fixture()
        let service = BottlePublicationService(maintenance: maintenance)
        let first = maintenance.store.root.appendingPathComponent("revision1.cruzadorbottle")
        let published = try await service.publish(bottleID: bottle.id, destination: first)
        XCTAssertTrue(published.entries.contains { $0.path == "Prefix/drive_c/test.exe" && $0.kind == "file" })
        XCTAssertTrue(published.entries.contains { $0.path == "Prefix/external-link" && $0.kind == "symlink" })
        let received = try service.receive(first, engine: bottle.engine)
        XCTAssertEqual(try service.managed(received.id).publicationID, published.id)
        XCTAssertEqual(received.state, .interrupted)
        let second = maintenance.store.root.appendingPathComponent("revision2.cruzadorbottle")
        try Data("new revision".utf8).write(to: maintenance.store.prefix(for: bottle).appendingPathComponent("drive_c/test.exe"))
        let revision = try await service.publish(bottleID: bottle.id, previous: first, destination: second)
        XCTAssertEqual(revision.id, published.id); XCTAssertEqual(revision.revision, 2)
        let updated = try service.receive(second, engine: bottle.engine, updating: received.id)
        XCTAssertNotEqual(updated.id, received.id)
        XCTAssertEqual(try service.managed(updated.id).previousBottleID, received.id)
        XCTAssertEqual(try String(contentsOf: maintenance.store.prefix(for: received).appendingPathComponent("drive_c/test.exe"), encoding: .utf8), "user data")
        XCTAssertEqual(try String(contentsOf: maintenance.store.prefix(for: updated).appendingPathComponent("drive_c/test.exe"), encoding: .utf8), "new revision")
        let before = try Data(contentsOf: maintenance.store.manifest)
        XCTAssertThrowsError(try service.receive(first, engine: bottle.engine, updating: updated.id))
        try Data("modified".utf8).write(to: second.appendingPathComponent("Prefix/drive_c/test.exe"))
        XCTAssertThrowsError(try service.receive(second, engine: bottle.engine))
        XCTAssertEqual(try Data(contentsOf: maintenance.store.manifest), before)
    }
}
