import Foundation

public enum InstallerDownloadPolicy: String, Codable, CaseIterable, Sendable {
    case allowNetwork, cachedOnly
    public var displayName: String { self == .allowNetwork ? "Permitir downloads das receitas" : "Usar somente instaladores em cache" }
}
public struct InstallerPreferences: Codable, Equatable, Sendable {
    public var formatVersion = 1
    public var defaultMSIMode: InstallerMode = .interactive
    public var downloadPolicy: InstallerDownloadPolicy = .allowNetwork
    public var cacheDirectory: String?
    public init() {}
    public func cacheRoot(library: LibraryStore) throws -> URL {
        guard formatVersion == 1 else { throw CruzadorError.invalid("Versão de preferências de instalação desconhecida.") }
        let root: URL
        if let path = cacheDirectory {
            guard path.hasPrefix("/"), !path.contains("\0") else { throw CruzadorError.invalid("Informe uma pasta absoluta para o cache, ou deixe o campo vazio para usar o padrão.") }
            root = URL(fileURLWithPath: path, isDirectory: true)
        } else { root = library.root.appendingPathComponent("Downloads") }
        do {
            guard try root.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw CruzadorError.invalid("O local de cache selecionado não é uma pasta.") }
        } catch CocoaError.fileReadNoSuchFile {} // An absent selected directory is created by the download owner.
        return root
    }
}
public struct InstallerPreferencesStore: Sendable {
    public let library: LibraryStore
    public var file: URL { library.root.appendingPathComponent("installer-preferences.json") }
    public init(library: LibraryStore) { self.library = library }
    public func load() throws -> InstallerPreferences {
        let data: Data
        do { data = try Data(contentsOf: file) } catch CocoaError.fileReadNoSuchFile { return InstallerPreferences() }
        let preferences = try JSONDecoder().decode(InstallerPreferences.self, from: data)
        _ = try preferences.cacheRoot(library: library)
        return preferences
    }
    public func save(_ preferences: InstallerPreferences) throws {
        _ = try preferences.cacheRoot(library: library)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(preferences)
        let previous: Data?
        do { previous = try Data(contentsOf: file) } catch CocoaError.fileReadNoSuchFile { previous = nil }
        if previous == data { return }
        try library.prepare()
        if let previous {
            let backups = library.root.appendingPathComponent("Backups"); try FileManager.default.createDirectory(at: backups, withIntermediateDirectories: true)
            try previous.write(to: backups.appendingPathComponent("installer-preferences-\(UUID()).json.bak"), options: .withoutOverwriting)
        }
        try data.write(to: file, options: .atomic)
    }
}
public enum CachedPayload: Sendable {
    case available(file: URL, bytes: Int64?)
    case missing
    case unavailable(String)
}
public struct CachedInstaller: Sendable {
    public let payload: CachedPayload
    public let receipt: URL
    public var ownedPaths: [URL] {
        if case .available(let file, _) = payload { return [receipt, file] }
        return [receipt]
    }
}
public struct InstallerCacheInventory: Sendable {
    public let entries: [CachedInstaller]
    public let unrecognized: [URL]
    public var ownedPaths: [URL] { entries.flatMap(\.ownedPaths) }
    public var availableCount: Int { entries.filter { if case .available = $0.payload { return true }; return false }.count }
    public var missingCount: Int { entries.filter { if case .missing = $0.payload { return true }; return false }.count }
    public var unavailableCount: Int { entries.count - availableCount - missingCount }
    public var knownBytes: Int64 { entries.reduce(0) { total, entry in if case .available(_, let size) = entry.payload { return total + (size ?? 0) }; return total } }
    /// Valid receipt identity establishes ownership; payload integrity is checked by ArtifactCache at reuse.
    public static func scan(root: URL) throws -> InstallerCacheInventory {
        let directories: [URL]
        do { directories = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) }
        catch CocoaError.fileReadNoSuchFile { return InstallerCacheInventory(entries: [], unrecognized: []) }
        var entries: [CachedInstaller] = [], unknown: [URL] = []
        for directory in directories {
            let facts = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard facts.isDirectory == true, facts.isSymbolicLink != true, directory.lastPathComponent.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else { unknown.append(directory); continue }
            let members = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            var recognized = Set<String>()
            for receipt in members where receipt.pathExtension == "json" && receipt.deletingPathExtension().pathExtension == "receipt" {
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: receipt.path), attributes[.type] as? FileAttributeType == .typeRegular,
                      let data = try? Data(contentsOf: receipt), let record = try? JSONDecoder().decode(ArtifactReceipt.self, from: data),
                      record.sha256 == directory.lastPathComponent, record.size >= 0, record.sourceURL.scheme?.lowercased() == "https" else { continue }
                let file = receipt.deletingPathExtension().deletingPathExtension()
                guard WindowsFileKind(rawValue: file.pathExtension.lowercased()) != nil else { continue }
                let payload: CachedPayload
                do {
                    let facts = try FileManager.default.attributesOfItem(atPath: file.path)
                    let type = facts[.type] as? FileAttributeType
                    if type == .typeRegular || type == .typeSymbolicLink {
                        payload = .available(file: file, bytes: type == .typeRegular ? (facts[.size] as? NSNumber)?.int64Value : nil)
                        recognized.insert(file.lastPathComponent)
                    } else { payload = .unavailable("O caminho do instalador não é arquivo ou link: " + file.path) }
                } catch CocoaError.fileReadNoSuchFile { payload = .missing }
                catch { payload = .unavailable(error.localizedDescription) }
                entries.append(CachedInstaller(payload: payload, receipt: receipt)); recognized.insert(receipt.lastPathComponent)
            }
            unknown += members.filter { !recognized.contains($0.lastPathComponent) }
        }
        return InstallerCacheInventory(entries: entries, unrecognized: unknown)
    }
}

public struct CacheTrashMove: Codable, Sendable {
    public let source: URL
    public let destination: URL?
}
public struct CacheCleanupResult: Codable, Sendable {
    public let moves: [CacheTrashMove]
    public let errors: [String]
    public let unrecognized: [URL]
}
public enum InstallerCacheCleaner {
    public static func systemTrash(_ file: URL) throws -> URL? {
        var destination: NSURL?
        try FileManager.default.trashItem(at: file, resultingItemURL: &destination)
        return destination.map { $0 as URL }
    }
    /// Preserve the receipt until moving its payload succeeded, retaining ownership on partial failure.
    public static func clear(root: URL, trash: (URL) throws -> URL? = systemTrash) throws -> CacheCleanupResult {
        let inventory = try InstallerCacheInventory.scan(root: root)
        var moves: [CacheTrashMove] = [], errors: [String] = []
        for entry in inventory.entries {
            switch entry.payload {
            case .available(let file, _):
                do { moves.append(CacheTrashMove(source: file, destination: try trash(file))) }
                catch { errors.append("\(file.path): \(error.localizedDescription). Recibo preservado em \(entry.receipt.path)."); continue }
            case .missing: break
            case .unavailable(let reason): errors.append(reason + ". Recibo preservado em " + entry.receipt.path); continue
            }
            do { moves.append(CacheTrashMove(source: entry.receipt, destination: try trash(entry.receipt))) }
            catch { errors.append("\(entry.receipt.path): \(error.localizedDescription)") }
        }
        return CacheCleanupResult(moves: moves, errors: errors, unrecognized: inventory.unrecognized)
    }
}
