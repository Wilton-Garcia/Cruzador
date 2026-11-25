import Foundation

public struct RuntimeMacOSVersion: Codable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public init(major: Int, minor: Int = 0, patch: Int = 0) { self.major = major; self.minor = minor; self.patch = patch }
}
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
    public let minimumMacOSVersion: RuntimeMacOSVersion?
    public let features: [String]?
    public init(formatVersion: Int = 1, identifier: String = "org.winehq.wine", version: String, sourceURL: String, sourceRevision: String, architectures: [String], wineExecutable: String = "bin/wine", serverExecutable: String = "bin/wineserver", licenseFiles: [String], minimumMacOSVersion: RuntimeMacOSVersion? = nil, features: [String]? = nil) {
        self.formatVersion = formatVersion; self.identifier = identifier; self.version = version
        self.sourceURL = sourceURL; self.sourceRevision = sourceRevision; self.architectures = architectures
        self.wineExecutable = wineExecutable; self.serverExecutable = serverExecutable; self.licenseFiles = licenseFiles
        self.minimumMacOSVersion = minimumMacOSVersion; self.features = features
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
        guard [1, 2].contains(decoded.formatVersion) else { throw WineRuntimeError.invalidManifest("versão de formato não suportada") }
        if decoded.formatVersion == 2 && decoded.minimumMacOSVersion == nil { throw WineRuntimeError.invalidManifest("o formato 2 exige a versão mínima do macOS") }
        if decoded.formatVersion == 1 && (decoded.minimumMacOSVersion != nil || decoded.features != nil) { throw WineRuntimeError.invalidManifest("metadados de plataforma e recursos exigem o formato 2") }
        if let minimum = decoded.minimumMacOSVersion {
            guard minimum.major > 0, minimum.minor >= 0, minimum.patch >= 0 else { throw WineRuntimeError.invalidManifest("versão mínima de macOS inválida") }
            guard ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: minimum.major, minorVersion: minimum.minor, patchVersion: minimum.patch)) else { throw WineRuntimeError.invalidManifest("este pacote exige macOS \(minimum.major).\(minimum.minor).\(minimum.patch); escolha um motor compatível") }
        }
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
