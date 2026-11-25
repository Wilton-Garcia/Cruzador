import Foundation

/// A reference into this library, never an embedded command or copied executable.
public struct LauncherReference: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let bottleID: UUID
    public let appID: UUID
    public init(bottleID: UUID, appID: UUID) { formatVersion = 1; self.bottleID = bottleID; self.appID = appID }
    public func resolve(in library: Library) throws -> (bottle: Bottle, app: WindowsApp) {
        guard formatVersion == 1 else { throw CruzadorError.invalid("Versão de atalho do Cruzador não suportada.") }
        guard let bottle = library.bottles.first(where: { $0.id == bottleID }), let app = bottle.apps.first(where: { $0.id == appID }) else { throw CruzadorError.invalid("O atalho não existe nesta biblioteca. Bottles importadas e duplicadas recebem novos identificadores; exporte outro atalho.") }
        return (bottle, app)
    }
    public var link: URL { URL(string: "cruzador://launch/\(bottleID.uuidString)/\(appID.uuidString)")! }
    public func write(to url: URL) throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "cruzadorapp" else { throw CruzadorError.invalid("Escolha um arquivo .cruzadorapp.") }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
public enum ExternalOpenTarget: Equatable, Sendable {
    case windowsFile(URL)
    case launcher(LauncherReference)
    case bottlePackage(URL)
    public static func parse(_ url: URL) throws -> ExternalOpenTarget {
        if url.isFileURL {
            guard url.host == nil || url.host == "" || url.host == "localhost" else { throw CruzadorError.invalid("Selecione um arquivo local.") }
            switch url.pathExtension.lowercased() {
            case "exe", "msi": return .windowsFile(url)
            case "cruzadorbottle":
                guard try FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path)[.type] as? FileAttributeType == .typeDirectory else { throw CruzadorError.invalid("A transferência deve ser uma pasta .cruzadorbottle.") }
                return .bottlePackage(url)
            case "cruzadorapp":
                guard try FileManager.default.attributesOfItem(atPath: url.resolvingSymlinksInPath().path)[.type] as? FileAttributeType == .typeRegular else { throw CruzadorError.invalid("O atalho deve ser um arquivo regular.") }
                let reference = try JSONDecoder().decode(LauncherReference.self, from: Data(contentsOf: url))
                guard reference.formatVersion == 1 else { throw CruzadorError.invalid("Versão de atalho do Cruzador não suportada.") }
                return .launcher(reference)
            default: throw CruzadorError.invalid("Abra um EXE, MSI, atalho .cruzadorapp ou pacote .cruzadorbottle.")
            }
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.scheme?.lowercased() == "cruzador", components.host == "launch", components.user == nil, components.password == nil, components.port == nil, components.query == nil, components.fragment == nil else { throw CruzadorError.invalid("Link do Cruzador inválido.") }
        let parts = components.path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].isEmpty, let bottle = UUID(uuidString: String(parts[1])), let app = UUID(uuidString: String(parts[2])) else { throw CruzadorError.invalid("O link deve identificar uma bottle e um atalho existentes.") }
        return .launcher(LauncherReference(bottleID: bottle, appID: app))
    }
}
public struct ExternalOpenRequest: Identifiable, Sendable {
    public let id = UUID()
    public let source: URL
    public let target: ExternalOpenTarget
    public init(source: URL) throws { self.source = source; target = try ExternalOpenTarget.parse(source) }
}
