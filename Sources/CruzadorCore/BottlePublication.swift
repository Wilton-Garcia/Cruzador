import Foundation

public struct PublicationEntry: Codable, Equatable, Sendable {
    public let path: String
    public let kind: String
    public let value: String
}
public struct BottlePublication: Codable, Sendable {
    public let formatVersion: Int
    public let id: UUID
    public let revision: Int
    public let publishedAt: Date
    public let entries: [PublicationEntry]
}
public struct ManagedBottle: Codable, Sendable {
    public let formatVersion: Int
    public let bottleID: UUID
    public let publicationID: UUID
    public let revision: Int
    public let source: URL
    public let publicationSHA256: String
    public let previousBottleID: UUID?
}
/// Immutable publication snapshots and side-by-side managed updates; no user prefix is overwritten.
public struct BottlePublicationService: Sendable {
    public let maintenance: BottleMaintenance
    public init(maintenance: BottleMaintenance) { self.maintenance = maintenance }
    public func inspect(_ package: URL) throws -> BottlePublication {
        let publication = try JSONDecoder().decode(BottlePublication.self, from: Data(contentsOf: package.appendingPathComponent("publication.json")))
        guard publication.formatVersion == 1, publication.revision > 0 else { throw CruzadorError.invalid("Versão de publicação desconhecida.") }
        let actual = try inventory(package)
        guard actual == publication.entries else {
            let changed = actual.first { !publication.entries.contains($0) }?.path ?? publication.entries.first { !actual.contains($0) }?.path ?? "ordenação do inventário"
            throw CruzadorError.invalid("Publicação alterada: \(changed). Preserve o pacote e obtenha uma cópia íntegra.")
        }
        return publication
    }
    public func publish(bottleID: UUID, previous: URL? = nil, destination: URL) async throws -> BottlePublication {
        let prior = try previous.map(inspect)
        guard prior?.revision != Int.max else { throw CruzadorError.invalid("A publicação atingiu o limite de revisões.") }
        try await maintenance.export(id: bottleID, destination: destination)
        let publication = BottlePublication(formatVersion: 1, id: prior?.id ?? UUID(), revision: (prior?.revision ?? 0) + 1, publishedAt: Date(), entries: try inventory(destination))
        try JSONEncoder().encode(publication).write(to: destination.appendingPathComponent("publication.json"), options: .withoutOverwriting)
        return publication
    }
    public func managed(_ id: UUID) throws -> ManagedBottle {
        let record = try JSONDecoder().decode(ManagedBottle.self, from: Data(contentsOf: recordPath(id)))
        guard record.formatVersion == 1, record.bottleID == id, record.revision > 0 else { throw CruzadorError.invalid("Referência de bottle gerenciada inválida.") }
        return record
    }
    public func receive(_ package: URL, engine: Engine, updating id: UUID? = nil) throws -> Bottle {
        let publication = try inspect(package)
        if let id {
            let previous = try managed(id)
            guard try maintenance.store.load().bottles.contains(where: { $0.id == id }), publication.id == previous.publicationID, publication.revision > previous.revision else { throw CruzadorError.invalid("Escolha uma revisão mais recente da mesma publicação. A bottle atual foi preservada.") }
        }
        let bottle = try maintenance.importBottle(from: package, engine: engine)
        let reference = ManagedBottle(formatVersion: 1, bottleID: bottle.id, publicationID: publication.id, revision: publication.revision, source: package, publicationSHA256: try ArtifactCache.sha256(of: package.appendingPathComponent("publication.json")), previousBottleID: id)
        let file = recordPath(bottle.id)
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(reference).write(to: file, options: .withoutOverwriting)
        } catch { throw CruzadorError.invalid("Bottle importada em \(maintenance.store.prefix(for: bottle).path), mas o vínculo gerenciado não foi salvo: \(error.localizedDescription). A cópia foi preservada na biblioteca.") }
        return bottle
    }
    private func recordPath(_ id: UUID) -> URL { maintenance.store.root.appendingPathComponent("Managed/\(id).json") }
    private func inventory(_ selected: URL) throws -> [PublicationEntry] {
        let rootFacts = try selected.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootFacts.isDirectory == true, rootFacts.isSymbolicLink != true else { throw CruzadorError.invalid("Selecione uma pasta de publicação regular.") }
        let package = selected.standardizedFileURL.resolvingSymlinksInPath()
        var directories = [package]
        var entries: [PublicationEntry] = []
        while let directory = directories.popLast() {
            for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey]) {
                let canonical = file.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(file.lastPathComponent)
                guard canonical.path.hasPrefix(package.path + "/") else { throw CruzadorError.invalid("Caminho fora da publicação: \(file.path)") }
                let path = String(canonical.path.dropFirst(package.path.count + 1))
                if path == "publication.json" { continue }
                let facts = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey])
                if facts.isSymbolicLink == true {
                    entries.append(PublicationEntry(path: path, kind: "symlink", value: try FileManager.default.destinationOfSymbolicLink(atPath: file.path)))
                } else if facts.isRegularFile == true { entries.append(PublicationEntry(path: path, kind: "file", value: try ArtifactCache.sha256(of: file))) }
                else if facts.isDirectory == true { entries.append(PublicationEntry(path: path, kind: "directory", value: "")); directories.append(canonical) }
                else { throw CruzadorError.invalid("Tipo de arquivo não suportado na publicação: \(file.path)") }
            }
        }
        return entries.sorted { $0.path < $1.path }
    }
}
