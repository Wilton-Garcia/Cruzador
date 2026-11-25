import Foundation

public enum LibraryObservation: Sendable {
    case absent
    case valid(library: Library, source: Data)
    case invalid(source: Data, reason: String)
}

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
    public func observe() throws -> LibraryObservation {
        let data: Data
        do { data = try Data(contentsOf: manifest) }
        catch { if Self.isMissingFile(error) { return .absent }; throw error }
        do {
            let library = try JSONDecoder().decode(Library.self, from: data)
            try validate(library)
            return .valid(library: library, source: data)
        } catch { return .invalid(source: data, reason: error.localizedDescription) }
    }
    public func load() throws -> Library {
        switch try observe() {
        case .absent: return Library()
        case .valid(let library, _): return library
        case .invalid(_, let reason): throw CruzadorError.invalid(reason)
        }
    }
    private static func isMissingFile(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && [CocoaError.fileNoSuchFile.rawValue, CocoaError.fileReadNoSuchFile.rawValue].contains(error.code)
    }
    public func migrateIfNeeded() throws {
        let library = try load()
        if library.version < Library.currentVersion { try save(library) }
    }
    private func validate(_ library: Library) throws {
        guard (1...Library.currentVersion).contains(library.version) else { throw CruzadorError.invalid("Versão da biblioteca não suportada. Preserve library.json antes de atualizar.") }
        guard Set(library.bottles.map(\.id)).count == library.bottles.count else { throw CruzadorError.invalid("Biblioteca com identificadores de bottle duplicados.") }
        if let selected = library.preferences.defaultBottleID, !library.bottles.contains(where: { $0.id == selected }) { throw CruzadorError.invalid("A bottle padrão não existe na biblioteca.") }
        for bottle in library.bottles {
            guard !bottle.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, bottle.engine.path.hasPrefix("/"), Set(bottle.apps.map(\.id)).count == bottle.apps.count,
                  Set((bottle.installations ?? []).map(\.id)).count == (bottle.installations ?? []).count else {
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
        func kind(_ path: URL) throws -> FileAttributeType? {
            try FileManager.default.attributesOfItem(atPath: path.resolvingSymlinksInPath().path)[.type] as? FileAttributeType
        }
        do { guard try kind(prefix) == .typeDirectory else { return .incomplete } }
        catch { return Self.isMissingFile(error) ? .absent : .unknown(error.localizedDescription) }
        let registry = prefix.appendingPathComponent("system.reg")
        do {
            guard try kind(registry) == .typeRegular, try kind(prefix.appendingPathComponent("drive_c")) == .typeDirectory else { return .incomplete }
        } catch { return Self.isMissingFile(error) ? .incomplete : .unknown(error.localizedDescription) }
        guard FileManager.default.isReadableFile(atPath: registry.path) else { return .unknown("O registro existe, mas não está legível: \(registry.path)") }
        return .initialized
    }
    public func isReady(_ bottle: Bottle) -> Bool { bottle.state == .ready && health(of: bottle) == .initialized }
    public func isInitialized(_ bottle: Bottle) -> Bool { health(of: bottle) == .initialized }
}
