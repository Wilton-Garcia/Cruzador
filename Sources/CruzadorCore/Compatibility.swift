import Foundation

public enum CompatibilityResult: String, Codable, CaseIterable, Sendable {
    case works, limited, fails
    public var displayName: String { switch self { case .works: "Funciona"; case .limited: "Funciona com limitações"; case .fails: "Não funciona" } }
}
public struct CompatibilityReport: Codable, Identifiable, Sendable {
    public var formatVersion = 1
    public let id: UUID
    public let observedAt: Date
    public let bottleID: UUID
    public let appID: UUID
    public let appName: String
    public let appVersion: String
    public let executableSHA256: String
    public let engine: Engine
    public let runtimeVersion: String?
    public let operatingSystem: String
    public let result: CompatibilityResult
    public let notes: String
    public let observationKind: String
}
public struct CompatibilityStore: Sendable {
    public let library: LibraryStore
    public var root: URL { library.root.appendingPathComponent("Compatibility") }
    public init(library: LibraryStore) { self.library = library }
    public func reports() throws -> [CompatibilityReport] {
        let files: [URL]
        do { files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) }
        catch CocoaError.fileReadNoSuchFile { return [] }
        return try files.filter { $0.pathExtension == "json" }.map { file in
            let facts = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard facts.isRegularFile == true, facts.isSymbolicLink != true else { throw CruzadorError.invalid("Avaliação não é arquivo regular: \(file.path)") }
            let report = try JSONDecoder().decode(CompatibilityReport.self, from: Data(contentsOf: file))
            guard report.formatVersion == 1, file.deletingPathExtension().lastPathComponent == report.id.uuidString,
                  report.observationKind == "manual-user-observation" else { throw CruzadorError.invalid("Avaliação desconhecida ou com identidade divergente: \(file.path)") }
            return report
        }.sorted { $0.observedAt > $1.observedAt }
    }
    @discardableResult public func record(bottleID: UUID, appID: UUID, appVersion: String, result: CompatibilityResult, notes: String) throws -> CompatibilityReport {
        let current = try library.load()
        guard let bottle = current.bottles.first(where: { $0.id == bottleID }), let app = bottle.apps.first(where: { $0.id == appID }) else { throw CruzadorError.invalid("O aplicativo não está mais nesta bottle.") }
        let version = appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty, !note.isEmpty else { throw CruzadorError.invalid("Informe a versão e descreva o que foi testado.") }
        _ = try WindowsFileInspection.inspect(path: app.path)
        let report = CompatibilityReport(id: UUID(), observedAt: Date(), bottleID: bottleID, appID: appID, appName: app.name, appVersion: version,
                                         executableSHA256: try ArtifactCache.sha256(of: URL(fileURLWithPath: app.path)), engine: bottle.engine,
                                         runtimeVersion: bottle.engine.kind == .packagedWine ? try WineRuntime(root: URL(fileURLWithPath: bottle.engine.path)).manifest.version : nil,
                                         operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString, result: result, notes: note, observationKind: "manual-user-observation")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(report).write(to: root.appendingPathComponent(report.id.uuidString + ".json"), options: .withoutOverwriting)
        return report
    }
    public func archive(id: UUID) throws {
        guard try reports().contains(where: { $0.id == id }) else { throw CruzadorError.invalid("Avaliação não encontrada.") }
        let archived = root.appendingPathComponent("Archived"); try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: root.appendingPathComponent(id.uuidString + ".json"), to: archived.appendingPathComponent(id.uuidString + ".json"))
    }
    public func export(to destination: URL) throws {
        struct Matrix: Encodable { let formatVersion = 1; let reports: [CompatibilityReport] }
        try JSONEncoder().encode(Matrix(reports: reports())).write(to: destination, options: .withoutOverwriting)
    }
}
