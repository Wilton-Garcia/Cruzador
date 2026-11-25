import Foundation

public struct BottleTransferManifest: Codable, Sendable {
    public let formatVersion: Int
    public let bottle: Bottle
    public let sourcePrefix: String
}

/// Copies links as links. Removal moves the complete record and prefix into
/// recovery storage; failed transfers retain their staging location for repair.
public struct BottleMaintenance: Sendable {
    public let store: LibraryStore
    public let runner: CommandRunner
    public let operationID: UUID
    public init(store: LibraryStore, runner: CommandRunner, operationID: UUID = UUID()) { self.store = store; self.runner = runner; self.operationID = operationID }

    public func rename(id: UUID, name: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CruzadorError.invalid("Informe um nome para a bottle.") }
        var library = try store.load()
        let index = try index(id, in: library)
        library.bottles[index].name = name
        try store.save(library)
    }
    public func duplicate(id: UUID, name: String) async throws -> Bottle {
        let library = try store.load(); let bottle = library.bottles[try index(id, in: library)]
        try await idle(bottle)
        return try receive(bottle: bottle, source: store.prefix(for: bottle), originalPrefix: store.prefix(for: bottle).path, name: name, engine: bottle.engine, requiresPreparation: false)
    }
    public func export(id: UUID, destination: URL) async throws {
        let library = try store.load(); let bottle = library.bottles[try index(id, in: library)]
        try await idle(bottle)
        try validatePrefix(store.prefix(for: bottle))
        let prefixPath = store.prefix(for: bottle).resolvingSymlinksInPath().path
        let destinationPath = destination.standardizedFileURL.resolvingSymlinksInPath().path
        guard !destinationPath.hasPrefix(prefixPath + "/") else { throw CruzadorError.invalid("Exporte para uma pasta fora da própria bottle.") }
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw CruzadorError.invalid("O destino já existe. Escolha um novo pacote para preservar os arquivos existentes.") }
        let stage = destination.deletingLastPathComponent().appendingPathComponent(".cruzador-transfer-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
            try FileManager.default.copyItem(at: store.prefix(for: bottle), to: stage.appendingPathComponent("Prefix"))
            try writeManifest(bottle, originalPrefix: store.prefix(for: bottle).path, to: stage)
            try FileManager.default.moveItem(at: stage, to: destination)
        } catch { throw CruzadorError.invalid("Exportação incompleta: \(error.localizedDescription). Arquivos parciais preservados em \(stage.path).") }
    }
    public func importBottle(from package: URL, engine: Engine) throws -> Bottle {
        let manifest = try JSONDecoder().decode(BottleTransferManifest.self, from: Data(contentsOf: package.appendingPathComponent("bottle.json")))
        guard manifest.formatVersion == 1, manifest.sourcePrefix.hasPrefix("/") else { throw CruzadorError.invalid("Formato de transferência não suportado.") }
        return try receive(bottle: manifest.bottle, source: package.appendingPathComponent("Prefix"), originalPrefix: manifest.sourcePrefix, name: manifest.bottle.name, engine: engine, requiresPreparation: true)
    }
    /// Recovery package can be imported later. No recursive deletion is performed.
    public func remove(id: UUID) async throws -> URL {
        var library = try store.load(); let selected = try index(id, in: library); let bottle = library.bottles[selected]
        if store.health(of: bottle) != .absent { try await idle(bottle) }
        let recovery = store.root.appendingPathComponent("Removed/\(UUID().uuidString).cruzadorbottle")
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        try writeManifest(bottle, originalPrefix: store.prefix(for: bottle).path, to: recovery)
        let source = store.prefix(for: bottle), retained = recovery.appendingPathComponent("Prefix")
        let hasPrefix = FileManager.default.fileExists(atPath: source.path)
        if hasPrefix { try FileManager.default.moveItem(at: source, to: retained) }
        library.bottles.remove(at: selected)
        if library.preferences.defaultBottleID == id { library.preferences.defaultBottleID = nil }
        do { try store.save(library) }
        catch {
            if hasPrefix {
                do { try FileManager.default.moveItem(at: retained, to: source) }
                catch { throw CruzadorError.invalid("Falha ao salvar e restaurar a bottle. Preserve \(recovery.path): \(error.localizedDescription)") }
            }
            throw error
        }
        return recovery
    }
    private func receive(bottle: Bottle, source: URL, originalPrefix: String, name: String, engine: Engine, requiresPreparation: Bool) throws -> Bottle {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CruzadorError.invalid("Informe um nome para a bottle.") }
        guard engine.kind != .crossOver else { throw CruzadorError.invalid("Selecione o Wine do Cruzador ou Wine externo para receber a bottle.") }
        try validatePrefix(source)
        var copy = Bottle(name: name, engine: engine)
        _ = try EngineCommands.make(.initialize, bottle: copy, store: store)
        let destination = store.prefix(for: copy)
        copy.apps = bottle.apps.map { app in
            var mapped = app
            mapped.id = UUID()
            mapped.path = relocate(app.path, from: originalPrefix, to: destination.path)
            if let working = app.options?.workingDirectory { mapped.options?.workingDirectory = relocate(working, from: originalPrefix, to: destination.path) }
            return mapped
        }
        copy.configuration = bottle.configuration
        copy.installations = bottle.installations
        copy.state = requiresPreparation ? .interrupted : bottle.state
        if requiresPreparation { copy.lastError = "Bottle importada. Prepare novamente com o motor selecionado antes de executar aplicativos." }
        try store.prepare()
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            try relocateLinks(in: destination, from: originalPrefix)
            var library = try store.load(); library.bottles.append(copy); try store.save(library)
        } catch { throw CruzadorError.invalid("Transferência incompleta: \(error.localizedDescription). Arquivos preservados em \(destination.path).") }
        return copy
    }
    private func idle(_ bottle: Bottle) async throws {
        let result = try await runner.run(EngineCommands.make(.waitForIdle, bottle: bottle, store: store), log: store.logsRoot.appendingPathComponent("maintenance-\(UUID().uuidString).log"), operationID: operationID)
        try result.requireSuccess()
    }
    private func index(_ id: UUID, in library: Library) throws -> Int {
        guard let found = library.bottles.firstIndex(where: { $0.id == id }) else { throw CruzadorError.invalid("Bottle não encontrada.") }
        return found
    }
    private func validatePrefix(_ prefix: URL) throws {
        for (url, directory) in [(prefix, true), (prefix.appendingPathComponent("drive_c"), true), (prefix.appendingPathComponent("system.reg"), false)] {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, directory ? values.isDirectory == true : values.isRegularFile == true else {
                throw CruzadorError.invalid("Prefixo de transferência inválido: \(url.path)")
            }
        }
    }
    private func writeManifest(_ bottle: Bottle, originalPrefix: String, to package: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(BottleTransferManifest(formatVersion: 1, bottle: bottle, sourcePrefix: originalPrefix)).write(to: package.appendingPathComponent("bottle.json"), options: .atomic)
    }
    private func relocate(_ path: String, from original: String, to destination: String) -> String {
        if path == original { return destination }
        if path.hasPrefix(original + "/") { return destination + path.dropFirst(original.count) }
        return path
    }
    private func relocateLinks(in prefix: URL, from original: String) throws {
        var traversalError: Error?
        guard let files = FileManager.default.enumerator(at: prefix, includingPropertiesForKeys: [.isSymbolicLinkKey], errorHandler: { _, error in traversalError = error; return false }) else { throw CruzadorError.invalid("Não foi possível percorrer a cópia em \(prefix.path).") }
        for case let url as URL in files {
            if try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true {
                let target = try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
                let mapped = relocate(target, from: original, to: prefix.path)
                if target != mapped {
                    try FileManager.default.removeItem(at: url)
                    try FileManager.default.createSymbolicLink(atPath: url.path, withDestinationPath: mapped)
                }
            }
        }
        if let traversalError { throw traversalError }
    }
}
