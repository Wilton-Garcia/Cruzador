import Foundation
import CryptoKit

public struct RegisteredSoftware: Identifiable, Codable, Sendable {
    public let id: String
    public let registryFile: String
    public let registrySHA256: String
    public let key: WineRegistryKey
    public let localInstallLocation: String?
    public var name: String? { key.string(named: "DisplayName") }
    public var version: String? { key.string(named: "DisplayVersion") }
    public var windowsInstallLocation: String? { key.string(named: "InstallLocation") }
}
public struct DiscoveredExecutable: Identifiable, Codable, Sendable {
    public let id: String
    public let inspection: WindowsFileInspection
    public let registeredSoftwareIDs: [String]
    public var name: String { URL(fileURLWithPath: inspection.path).deletingPathExtension().lastPathComponent }
}
public struct AppDiscoveryReport: Codable, Sendable {
    public let bottleID: UUID
    public let observedAt: Date
    public let scannedRoots: [String]
    public let absentRoots: [String]
    public let registeredSoftware: [RegisteredSoftware]
    public let executables: [DiscoveredExecutable]
    public let warnings: [String]
    public let limitations: [String]
}
public struct AppDiscovery: Sendable {
    public let store: LibraryStore
    public init(store: LibraryStore) { self.store = store }
    public func scan(_ bottle: Bottle) throws -> AppDiscoveryReport {
        let prefix = store.prefix(for: bottle)
        let prefixFacts = try prefix.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard prefixFacts.isDirectory == true, prefixFacts.isSymbolicLink != true else { throw CruzadorError.invalid("O prefixo da bottle precisa ser uma pasta local, não um link.") }
        var registered: [RegisteredSoftware] = [], warnings: [String] = [], scanned: [String] = [], absent: [String] = []
        for name in ["system.reg", "user.reg"] {
            let file = prefix.appendingPathComponent(name)
            do {
                let attributes = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard attributes.isRegularFile == true, attributes.isSymbolicLink != true else { throw CruzadorError.invalid("O registro não é um arquivo regular local.") }
                let data = try Data(contentsOf: file)
                guard let text = String(data: data, encoding: .utf8) else { throw CruzadorError.invalid("Registro não está em UTF-8 válido.") }
                let document = WineRegistryDocument(text: text) { key in
                    let key = key.lowercased()
                    for root in ["software\\microsoft\\windows\\currentversion\\uninstall\\", "software\\wow6432node\\microsoft\\windows\\currentversion\\uninstall\\"] {
                        if key.hasPrefix(root), !key.dropFirst(root.count).isEmpty, !key.dropFirst(root.count).contains("\\") { return true }
                    }
                    return false
                }
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                registered += document.keys.map { RegisteredSoftware(id: name + ":" + $0.path + ":" + String($0.line), registryFile: file.path, registrySHA256: digest, key: $0, localInstallLocation: $0.string(named: "InstallLocation").flatMap { localPath($0, prefix: prefix)?.path }) }
                warnings += document.warnings.map { name + ": " + $0 }; scanned.append(file.path)
            } catch {
                if isAbsent(error) { absent.append(file.path) }
                else { warnings.append("\(file.path): \(error.localizedDescription)") }
            }
        }
        var candidates: [DiscoveredExecutable] = []
        for rootName in ["Program Files", "Program Files (x86)"] {
            let root = prefix.appendingPathComponent("drive_c/" + rootName)
            let rootValues: URLResourceValues
            do { rootValues = try root.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) }
            catch {
                if isAbsent(error) { absent.append(root.path) } else { warnings.append("\(root.path): \(error.localizedDescription)") }
                continue
            }
            guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else { warnings.append("Raiz não percorrida por ser link ou não ser pasta: \(root.path)"); continue }
            scanned.append(root.path)
            guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey], errorHandler: { url, error in warnings.append("\(url.path): \(error.localizedDescription)"); return true }) else { warnings.append("Não foi possível percorrer \(root.path)"); continue }
            for case let file as URL in files {
                try Task.checkCancellation()
                do {
                    let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey])
                    if values.isSymbolicLink == true { files.skipDescendants(); continue }
                    guard values.isRegularFile == true, file.pathExtension.lowercased() == "exe" else { continue }
                    let inspection = try WindowsFileInspection.inspect(path: file.path)
                    let related = registered.compactMap { item -> String? in
                        guard let location = item.localInstallLocation else { return nil }
                        let candidate = file.standardizedFileURL.path.lowercased(), folder = location.lowercased()
                        return candidate.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/") ? item.id : nil
                    }
                    candidates.append(DiscoveredExecutable(id: String(file.path.dropFirst(prefix.path.count)), inspection: inspection, registeredSoftwareIDs: related))
                } catch is CancellationError { throw CancellationError() }
                catch { warnings.append("\(file.path): \(error.localizedDescription)") }
            }
        }
        return AppDiscoveryReport(bottleID: bottle.id, observedAt: Date(), scannedRoots: scanned, absentRoots: absent, registeredSoftware: registered,
                                  executables: candidates.sorted { $0.inspection.path < $1.inspection.path }, warnings: warnings,
                                  limitations: ["Observações de arquivos, sem snapshot atômico do registro ou do disco.", "Busca limitada a Program Files e Program Files (x86) do prefixo, sem seguir links de diretórios.", "Aplicativos portáteis, instalação por usuário, unidades externas e atalhos .lnk não são enumerados nesta busca.", "Presença no registro e cabeçalho PE não comprovam que o programa funcione."])
    }
    public func add(ids: Set<String>, from report: AppDiscoveryReport) throws {
        var library = try store.load()
        guard let index = library.bottles.firstIndex(where: { $0.id == report.bottleID }) else { throw CruzadorError.invalid("Bottle não encontrada.") }
        guard ids.isSubset(of: Set(report.executables.map(\.id))) else { throw CruzadorError.invalid("A seleção não pertence ao resultado da busca.") }
        let prefix = store.prefix(for: library.bottles[index]).resolvingSymlinksInPath().path
        for candidate in report.executables where ids.contains(candidate.id) {
            guard URL(fileURLWithPath: candidate.inspection.path).resolvingSymlinksInPath().path.hasPrefix(prefix + "/") else { throw CruzadorError.invalid("O executável encontrado não pertence mais ao prefixo da bottle.") }
            try candidate.inspection.validateCurrentMetadata()
            try LaunchRequest(path: candidate.inspection.path).validate()
            if !library.bottles[index].apps.contains(where: { $0.path == candidate.inspection.path && $0.arguments.isEmpty }) {
                library.bottles[index].apps.append(WindowsApp(name: candidate.name, path: candidate.inspection.path))
            }
        }
        try store.save(library)
    }
    private func isAbsent(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code)
    }
    private func localPath(_ windows: String, prefix: URL) -> URL? {
        let units = Array(windows.utf16)
        guard units.count >= 3, units[1] == 58, [92, 47].contains(units[2]), let drive = UnicodeScalar(units[0]), CharacterSet.letters.contains(drive) else { return nil }
        let link = prefix.appendingPathComponent("dosdevices/" + String(drive).lowercased() + ":")
        guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: link.path) else { return nil }
        let base = target.hasPrefix("/") ? URL(fileURLWithPath: target) : link.deletingLastPathComponent().appendingPathComponent(target)
        let relative = String(decoding: units.dropFirst(3), as: UTF16.self).replacingOccurrences(of: "\\", with: "/")
        let result = base.appendingPathComponent(relative).standardizedFileURL.resolvingSymlinksInPath()
        let boundary = prefix.resolvingSymlinksInPath().path
        return result.path.hasPrefix(boundary + "/") ? result : nil
    }
}
