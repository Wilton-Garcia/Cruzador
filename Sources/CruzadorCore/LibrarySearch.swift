import Foundation

public struct LibrarySearchMatch: Sendable {
    public let bottle: Bottle
    public let apps: [WindowsApp]
}
/// One owner for sidebar and application-grid search, preserving source identities and order.
public struct LibrarySearch: Sendable {
    public let text: String
    private let term: String
    public var isFiltering: Bool { !term.isEmpty }
    public init(text: String) { self.text = text; term = text.trimmingCharacters(in: .whitespacesAndNewlines) }
    public func results(in library: Library) -> [LibrarySearchMatch] {
        library.bottles.compactMap { bottle in
            if !isFiltering || contains(bottle.name) { return LibrarySearchMatch(bottle: bottle, apps: bottle.apps) }
            let apps = bottle.apps.filter { contains($0.name) || contains(URL(fileURLWithPath: $0.path).lastPathComponent) }
            return apps.isEmpty ? nil : LibrarySearchMatch(bottle: bottle, apps: apps)
        }
    }
    private func contains(_ value: String) -> Bool { value.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
}
