import Foundation
import CryptoKit

public struct InstallerArtifact: Codable, Sendable {
    public let id: String
    public let filename: String
    public let kind: WindowsFileKind
    public let url: URL
    public let sha256: String
    public let size: Int64
    public let upstream: URL
    public let release: URL
    private enum CodingKeys: String, CodingKey { case id, filename, url, sha256, size, upstream, release }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id); filename = try values.decode(String.self, forKey: .filename)
        url = try values.decode(URL.self, forKey: .url); sha256 = try values.decode(String.self, forKey: .sha256)
        size = try values.decode(Int64.self, forKey: .size); upstream = try values.decode(URL.self, forKey: .upstream); release = try values.decode(URL.self, forKey: .release)
        guard let kind = WindowsFileKind(rawValue: URL(fileURLWithPath: filename).pathExtension.lowercased()) else { throw CruzadorError.invalid("Formato de artefato inválido: \(id)") }
        self.kind = kind
        guard !id.isEmpty, filename == URL(fileURLWithPath: filename).lastPathComponent, !filename.isEmpty,
              [url, upstream, release].allSatisfy({ $0.scheme?.lowercased() == "https" && $0.host != nil }), size > 0,
              sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else { throw CruzadorError.invalid("Artefato de receita inválido: \(id)") }
    }
}
public struct RecipeShortcut: Codable, Sendable {
    public let name: String
    public let relativePath: String
    public let arguments: [String]
}
public struct InstallationRecipe: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let summary: String
    public let homepage: URL
    public let dependencies: [String]
    public let installerArtifactID: String
    public let mode: InstallerMode
    public let arguments: [String]
    public let shortcuts: [RecipeShortcut]
}
private struct CatalogDocument: Codable { let formatVersion: Int; let artifacts: [InstallerArtifact]; let recipes: [InstallationRecipe] }
public struct RecipeCatalog: Sendable {
    public let recipes: [InstallationRecipe]
    private let artifacts: [String: InstallerArtifact]
    private let byID: [String: InstallationRecipe]
    private let ordered: [InstallationRecipe]
    public static var bundledURL: URL { (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("recipes.json") }
    public init(data: Data) throws {
        let document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        guard document.formatVersion == 1 else { throw CruzadorError.invalid("Versão de catálogo de receitas não suportada.") }
        guard Set(document.artifacts.map(\.id)).count == document.artifacts.count, Set(document.recipes.map(\.id)).count == document.recipes.count else { throw CruzadorError.invalid("Catálogo com identificadores duplicados.") }
        let artifacts = Dictionary(uniqueKeysWithValues: document.artifacts.map { ($0.id, $0) })
        let recipes = Dictionary(uniqueKeysWithValues: document.recipes.map { ($0.id, $0) })
        for recipe in document.recipes {
            guard !recipe.id.isEmpty, !recipe.name.isEmpty, !recipe.version.isEmpty, recipe.homepage.scheme == "https", artifacts[recipe.installerArtifactID] != nil,
                  Set(recipe.dependencies).count == recipe.dependencies.count, recipe.dependencies.allSatisfy({ recipes[$0] != nil }), !recipe.arguments.contains(where: { $0.contains("\0") }) else { throw CruzadorError.invalid("Receita inválida ou dependência ausente: \(recipe.id)") }
            if artifacts[recipe.installerArtifactID]?.kind == .exe && recipe.mode != .interactive { throw CruzadorError.invalid("Receitas EXE usam argumentos do fornecedor, não modos de interface MSI.") }
            for shortcut in recipe.shortcuts {
                let parts = shortcut.relativePath.split(separator: "/", omittingEmptySubsequences: false)
                guard !parts.isEmpty, !parts.contains(""), !parts.contains(".."), !parts.contains("."), !shortcut.name.isEmpty, !shortcut.relativePath.contains("\0"), !shortcut.arguments.contains(where: { $0.contains("\0") }) else { throw CruzadorError.invalid("Atalho inválido na receita \(recipe.id)") }
            }
        }
        var visited: Set<String> = [], visiting: Set<String> = [], ordered: [InstallationRecipe] = []
        for recipe in document.recipes {
            var stack = [(recipe.id, false)]
            while let (id, expanded) = stack.popLast() {
                if visited.contains(id) { continue }
                guard let item = recipes[id] else { throw CruzadorError.invalid("Dependência ausente: \(id)") }
                if expanded { visiting.remove(id); visited.insert(id); ordered.append(item); continue }
                guard visiting.insert(id).inserted else { throw CruzadorError.invalid("Ciclo de dependências na receita \(id)") }
                stack.append((id, true))
                stack.append(contentsOf: item.dependencies.reversed().map { ($0, false) })
            }
        }
        self.recipes = document.recipes; self.artifacts = artifacts; byID = recipes; self.ordered = ordered
    }
    public func plan(for id: String) throws -> [InstallationRecipe] {
        guard byID[id] != nil else { throw CruzadorError.invalid("Receita não encontrada: \(id)") }
        var required: Set<String> = [], queue = [id], cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]; cursor += 1
            if required.insert(current).inserted {
                guard let recipe = byID[current] else { throw CruzadorError.invalid("Dependência não encontrada: \(current)") }
                queue.append(contentsOf: recipe.dependencies)
            }
        }
        return ordered.filter { required.contains($0.id) }
    }
    public func artifact(for recipe: InstallationRecipe) throws -> InstallerArtifact {
        guard let artifact = artifacts[recipe.installerArtifactID] else { throw CruzadorError.invalid("Artefato da receita não encontrado.") }
        return artifact
    }
}

private final class ExpectedDownloadSize: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let expected: Int64
    private let lock = NSLock()
    private var exceededLimit = false
    var exceeded: Bool { lock.withLock { exceededLimit } }
    init(expected: Int64) { self.expected = expected }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > expected { lock.withLock { exceededLimit = true }; downloadTask.cancel() }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
public struct ArtifactReceipt: Codable, Sendable {
    public let sourceURL: URL
    public let sha256: String
    public let size: Int64
    public let downloadedAt: Date
}
public actor ArtifactCache {
    public let root: URL
    private var downloading = false
    public let downloadPolicy: InstallerDownloadPolicy
    public init(root: URL, downloadPolicy: InstallerDownloadPolicy = .allowNetwork) { self.root = root; self.downloadPolicy = downloadPolicy }
    public static func sha256(of path: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: path); defer { try? file.close() }
        var hash = SHA256()
        while let block = try file.read(upToCount: 1024 * 1024), !block.isEmpty { try Task.checkCancellation(); hash.update(data: block) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    public func cachedPath(for artifact: InstallerArtifact) -> URL { root.appendingPathComponent(artifact.sha256).appendingPathComponent(artifact.filename) }
    public func fetch(_ artifact: InstallerArtifact) async throws -> URL {
        try Task.checkCancellation()
        guard !downloading else { throw CruzadorError.invalid("Já há um download de receita em andamento.") }
        let destination = cachedPath(for: artifact)
        if FileManager.default.fileExists(atPath: destination.path) { try verify(destination, artifact: artifact); return destination }
        guard downloadPolicy == .allowNetwork else { throw CruzadorError.invalid("Instalador ausente do cache selecionado: \(destination.path). Permita downloads nas preferências de instalação ou escolha um cache que já contenha o arquivo verificado.") }
        downloading = true; defer { downloading = false }
        let limiter = ExpectedDownloadSize(expected: artifact.size)
        let download: URL, response: URLResponse
        do { (download, response) = try await URLSession.shared.download(for: URLRequest(url: artifact.url), delegate: limiter) }
        catch {
            if limiter.exceeded { throw CruzadorError.invalid("O download excedeu os \(artifact.size) bytes declarados. Confira a origem e o catálogo antes de tentar novamente.") }
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
        let incoming = root.appendingPathComponent(".incoming-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: download, to: incoming)
        } catch { throw CruzadorError.invalid("Não foi possível guardar o download: \(error.localizedDescription). Preserve o arquivo temporário em \(download.path).") }
        do {
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw CruzadorError.invalid("O servidor não entregou o instalador solicitado.") }
            try verify(incoming, artifact: artifact)
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: incoming, to: destination)
        } catch { throw CruzadorError.invalid("Download não admitido: \(error.localizedDescription). Arquivo preservado em \(incoming.path).") }
        let receipt = ArtifactReceipt(sourceURL: artifact.url, sha256: artifact.sha256, size: artifact.size, downloadedAt: Date())
        try JSONEncoder().encode(receipt).write(to: destination.appendingPathExtension("receipt.json"), options: .atomic)
        return destination
    }
    private func verify(_ path: URL, artifact: InstallerArtifact) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        guard (attributes[.size] as? NSNumber)?.int64Value == artifact.size, try Self.sha256(of: path) == artifact.sha256 else { throw CruzadorError.invalid("O instalador não corresponde ao tamanho e SHA-256 fixados. Preserve \(path.path) antes de tentar novamente.") }
    }
}

public struct RecipeInstallationService: Sendable {
    public let store: LibraryStore
    public let runner: CommandRunner
    public let cache: ArtifactCache
    public let operationID: UUID
    public init(store: LibraryStore, runner: CommandRunner, cache: ArtifactCache, operationID: UUID = UUID()) { self.store = store; self.runner = runner; self.cache = cache; self.operationID = operationID }
    public func install(id: String, bottleID: UUID, catalog: RecipeCatalog, progress: @Sendable (String) async -> Void = { _ in }) async throws -> [UUID] {
        let steps = try catalog.plan(for: id)
        let initial = try store.load()
        guard let target = initial.bottles.first(where: { $0.id == bottleID }), store.isReady(target) else { throw CruzadorError.invalid("Prepare a bottle antes de instalar receitas.") }
        var records: [UUID] = []
        for recipe in steps {
            try Task.checkCancellation()
            let asset = try catalog.artifact(for: recipe)
            await progress("Baixando e verificando \(recipe.name) \(recipe.version)…")
            let source = try await cache.fetch(asset)
            try Task.checkCancellation()
            let library = try store.load()
            guard let bottle = library.bottles.first(where: { $0.id == bottleID }) else { throw CruzadorError.invalid("Bottle não encontrada.") }
            let request = try InstallationRequest(path: source.path, mode: recipe.mode, arguments: recipe.arguments, recipeID: recipe.id, sourceURL: asset.url, sourceSHA256: asset.sha256)
            await progress("Instalando \(recipe.name) \(recipe.version)…")
            _ = try await InstallationService(store: store).run(request, bottle: bottle, runner: runner, log: store.logsRoot.appendingPathComponent("recipe-\(request.id).log"), operationID: operationID)
            try Task.checkCancellation()
            var next = try store.load()
            guard let index = next.bottles.firstIndex(where: { $0.id == bottleID }) else { throw CruzadorError.invalid("Bottle não encontrada depois de instalar a receita.") }
            for shortcut in recipe.shortcuts {
                let path = store.prefix(for: bottle).appendingPathComponent(shortcut.relativePath)
                let request = LaunchRequest(path: path.path, arguments: shortcut.arguments)
                try request.validate()
                if !next.bottles[index].apps.contains(where: { $0.path == path.path && $0.arguments == shortcut.arguments }) {
                    next.bottles[index].apps.append(WindowsApp(name: shortcut.name, path: path.path, arguments: shortcut.arguments))
                }
            }
            try store.save(next); records.append(request.id)
        }
        return records
    }
}
