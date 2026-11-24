import Foundation

/// Single owner of persisted metadata and UUID-derived prefix paths.
public struct LibraryStore: Sendable {
    public let root: URL
    public init(root: URL) { self.root = root.standardizedFileURL }
    public static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Cruzador", isDirectory: true)
    }
    public var manifest: URL { root.appendingPathComponent("library.json") }
    public var bottlesRoot: URL { root.appendingPathComponent("Bottles", isDirectory: true) }
    public var logsRoot: URL { root.appendingPathComponent("Logs", isDirectory: true) }
    public func prefix(for bottle: Bottle) -> URL { bottlesRoot.appendingPathComponent(bottle.id.uuidString, isDirectory: true) }
    public func prepare() throws {
        for url in [root, bottlesRoot, logsRoot] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    }
    public func load() throws -> Library {
        if !FileManager.default.fileExists(atPath: manifest.path) { return Library() }
        let library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: manifest))
        guard library.version == 1 else { throw CruzadorError.invalid("Versão da biblioteca não suportada. Preserve library.json antes de atualizar.") }
        guard Set(library.bottles.map(\.id)).count == library.bottles.count else { throw CruzadorError.invalid("Biblioteca com identificadores de bottle duplicados.") }
        return library
    }
    public func save(_ library: Library) throws {
        try prepare()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(library)
        if FileManager.default.fileExists(atPath: manifest.path) {
            // Validate the current file before replacing it; preserve malformed evidence.
            _ = try load()
            try Data(contentsOf: manifest).write(to: root.appendingPathComponent("library.json.bak"), options: .atomic)
        }
        try data.write(to: manifest, options: .atomic)
    }
    public func isInitialized(_ bottle: Bottle) -> Bool {
        let prefix = prefix(for: bottle)
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: prefix.appendingPathComponent("system.reg").path)
            && FileManager.default.fileExists(atPath: prefix.appendingPathComponent("drive_c").path, isDirectory: &directory) && directory.boolValue
    }
}
