import XCTest
@testable import CruzadorCore

final class ApplicationLibrarySelectionTests: XCTestCase {
    func testExplicitLibraryPreservesFilePathSemanticsAndInvalidInputCannotFallBack() throws {
        XCTAssertNil(try ApplicationLibrarySelection.resolve(arguments: []).get())
        let selected = try XCTUnwrap(try ApplicationLibrarySelection.resolve(arguments: ["--library-root", "/tmp/literal %2F and spaces"]).get())
        XCTAssertEqual(selected.path, "/tmp/literal %2F and spaces")
        for arguments in [["--library-root"], ["--library-root", "relative"], ["--library-root", "/tmp/one", "--library-root", "/tmp/two"]] {
            XCTAssertThrowsError(try ApplicationLibrarySelection.resolve(arguments: arguments).get())
        }
    }
}
