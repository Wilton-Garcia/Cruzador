import XCTest
@testable import CruzadorCore

final class LibrarySearchTests: XCTestCase {
    func testSearchProjectsMatchingAppsWithoutChangingIdentityOrLibrary() {
        var work = Bottle(name: "Trabalho", engine: Engine(kind: .wine, path: "/bin/wine"))
        work.apps = [WindowsApp(name: "Editor", path: "/prefix/paint.exe"), WindowsApp(name: "Café", path: "/prefix/cafe.exe")]
        var other = Bottle(name: "Jogos", engine: work.engine)
        other.apps = [WindowsApp(name: "Editor", path: "/other/edit.exe")]
        var library = Library(); library.bottles = [work, other]
        let search = LibrarySearch(text: "  CAFE  "), matches = search.results(in: library)
        XCTAssertEqual(search.text, "  CAFE  "); XCTAssertTrue(search.isFiltering)
        XCTAssertEqual(matches.map(\.bottle.id), [work.id])
        XCTAssertEqual(matches[0].apps.map(\.id), [work.apps[1].id])
        XCTAssertEqual(matches[0].bottle.apps.count, 2)
        XCTAssertEqual(LibrarySearch(text: "paint.EXE").results(in: library)[0].apps[0].id, work.apps[0].id)
        XCTAssertEqual(LibrarySearch(text: "Editor").results(in: library).flatMap(\.apps).map(\.id), [work.apps[0].id, other.apps[0].id])
        XCTAssertTrue(LibrarySearch(text: "not found").results(in: library).isEmpty)
    }
    func testBottleNameAndEmptySearchKeepAllApplicationsAndEmptyBottles() {
        var bottle = Bottle(name: "Ambiente", engine: Engine(kind: .wine, path: "/bin/wine"))
        bottle.apps = [WindowsApp(name: "A", path: "/a.exe"), WindowsApp(name: "B", path: "/b.exe")]
        let empty = Bottle(name: "Vazia", engine: bottle.engine)
        var library = Library(); library.bottles = [bottle, empty]
        XCTAssertEqual(LibrarySearch(text: "ambiente").results(in: library)[0].apps, bottle.apps)
        XCTAssertEqual(LibrarySearch(text: "Vazia").results(in: library)[0].bottle.id, empty.id)
        XCTAssertFalse(LibrarySearch(text: " \n").isFiltering)
        XCTAssertEqual(LibrarySearch(text: " \n").results(in: library).map(\.bottle.id), [bottle.id, empty.id])
    }
}
