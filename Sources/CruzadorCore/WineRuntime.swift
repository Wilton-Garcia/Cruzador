import Foundation

public struct WineRuntimeManifest: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let identifier: String
    public let version: String
    public let sourceURL: String
    public let sourceRevision: String
    public let architectures: [String]
    public let wineExecutable: String
    public let serverExecutable: String
    public let licenseFiles: [String]
    public init(formatVersion: Int = 1, identifier: String = "org.winehq.wine", version: String, sourceURL: String, sourceRevision: String, architectures: [String], wineExecutable: String = "bin/wine", serverExecutable: String = "bin/wineserver", licenseFiles: [String]) {
        self.formatVersion = formatVersion; self.identifier = identifier; self.version = version
        self.sourceURL = sourceURL; self.sourceRevision = sourceRevision; self.architectures = architectures
        self.wineExecutable = wineExecutable; self.serverExecutable = serverExecutable; self.licenseFiles = licenseFiles
    }
}
public enum WineRuntimeError: LocalizedError {
    case missingManifest(String)
    case invalidManifest(String)
    case missingComponent(String)
    public var errorDescription: String? {
        switch self {
        case .missingManifest(let path): "Motor do Cruzador ausente. Prepare um pacote Wine com runtime.json em \(path)."
        case .invalidManifest(let reason): "Pacote Wine inválido: \(reason)"
        case .missingComponent(let path): "Componente ausente ou indisponível no pacote Wine: \(path)"
        }
    }
}
/// Owns parsing and path resolution of a packaged engine; never falls back to CrossOver.
public struct WineRuntime: Sendable {
    public let root: URL
    public let manifest: WineRuntimeManifest
    public let wine: URL
    public let server: URL
    public static var bundledRoot: URL {
        (Bundle.main.resourceURL ?? Bundle.main.bundleURL).appendingPathComponent("Runtime", isDirectory: true)
    }
    public init(root: URL) throws {
        let canonical = root.standardizedFileURL.resolvingSymlinksInPath()
        let path = canonical.appendingPathComponent("runtime.json")
        guard FileManager.default.fileExists(atPath: path.path) else { throw WineRuntimeError.missingManifest(path.path) }
        let decoded: WineRuntimeManifest
        do { decoded = try JSONDecoder().decode(WineRuntimeManifest.self, from: Data(contentsOf: path)) }
        catch { throw WineRuntimeError.invalidManifest(error.localizedDescription) }
        guard decoded.formatVersion == 1 else { throw WineRuntimeError.invalidManifest("versão de formato não suportada") }
        guard decoded.identifier == "org.winehq.wine", !decoded.version.isEmpty, !decoded.sourceURL.isEmpty, !decoded.sourceRevision.isEmpty, !decoded.architectures.isEmpty, !decoded.licenseFiles.isEmpty else {
            throw WineRuntimeError.invalidManifest("identidade, versão, proveniência, arquiteturas e licenças são obrigatórias")
        }
        func component(_ relative: String, executable: Bool) throws -> URL {
            let pieces = relative.split(separator: "/", omittingEmptySubsequences: false)
            guard !relative.hasPrefix("/"), !pieces.isEmpty, !pieces.contains(".."), !pieces.contains("") else {
                throw WineRuntimeError.invalidManifest("caminho de componente deve ser relativo ao pacote: \(relative)")
            }
            let selected = canonical.appendingPathComponent(relative).resolvingSymlinksInPath()
            guard selected.path.hasPrefix(canonical.path + "/") else { throw WineRuntimeError.invalidManifest("componente aponta para fora do pacote: \(relative)") }
            var directory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: selected.path, isDirectory: &directory), !directory.boolValue,
                  executable ? FileManager.default.isExecutableFile(atPath: selected.path) : FileManager.default.isReadableFile(atPath: selected.path) else {
                throw WineRuntimeError.missingComponent(relative)
            }
            return selected
        }
        self.wine = try component(decoded.wineExecutable, executable: true)
        self.server = try component(decoded.serverExecutable, executable: true)
        for license in decoded.licenseFiles { _ = try component(license, executable: false) }
        self.root = canonical; self.manifest = decoded
    }
}
