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
        try validate(library)
        return library
    }
    public func migrateIfNeeded() throws {
        let library = try load()
        if library.version < Library.currentVersion { try save(library) }
    }
    private func validate(_ library: Library) throws {
        guard [1, Library.currentVersion].contains(library.version) else { throw CruzadorError.invalid("Versão da biblioteca não suportada. Preserve library.json antes de atualizar.") }
        guard Set(library.bottles.map(\.id)).count == library.bottles.count else { throw CruzadorError.invalid("Biblioteca com identificadores de bottle duplicados.") }
        if let selected = library.preferences.defaultBottleID, !library.bottles.contains(where: { $0.id == selected }) { throw CruzadorError.invalid("A bottle padrão não existe na biblioteca.") }
        for bottle in library.bottles {
            guard !bottle.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, bottle.engine.path.hasPrefix("/"), Set(bottle.apps.map(\.id)).count == bottle.apps.count else {
                throw CruzadorError.invalid("Metadados inválidos na bottle \(bottle.id). Preserve o manifesto para diagnóstico.")
            }
        }
    }
    public func save(_ library: Library) throws {
        try validate(library)
        var normalized = library; normalized.version = Library.currentVersion
        try prepare()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalized)
        if FileManager.default.fileExists(atPath: manifest.path) {
            // Validate the current file before replacing it; preserve malformed evidence.
            let previous = try load()
            let original = try Data(contentsOf: manifest)
            if original == data { return }
            if previous.version < Library.currentVersion {
                let backup = root.appendingPathComponent("library-v\(previous.version).json.bak")
                if !FileManager.default.fileExists(atPath: backup.path) { try original.write(to: backup, options: .withoutOverwriting) }
            }
            try original.write(to: root.appendingPathComponent("library.json.bak"), options: .atomic)
        }
        try data.write(to: manifest, options: .atomic)
    }
    public func health(of bottle: Bottle) -> PrefixHealth {
        let prefix = prefix(for: bottle)
        guard FileManager.default.fileExists(atPath: prefix.path) else { return .absent }
        var directory: ObjCBool = false
        var registryDirectory: ObjCBool = false
        let registry = prefix.appendingPathComponent("system.reg")
        let valid = FileManager.default.fileExists(atPath: registry.path, isDirectory: &registryDirectory) && !registryDirectory.boolValue
            && FileManager.default.isReadableFile(atPath: registry.path)
            && FileManager.default.fileExists(atPath: prefix.appendingPathComponent("drive_c").path, isDirectory: &directory) && directory.boolValue
        return valid ? .initialized : .incomplete
    }
    public func isInitialized(_ bottle: Bottle) -> Bool { health(of: bottle) == .initialized }
}
