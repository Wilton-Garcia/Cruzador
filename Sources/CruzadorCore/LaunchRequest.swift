import Foundation

public struct LaunchOptions: Codable, Equatable, Sendable {
    public var workingDirectory: String?
    public var environment: [String: String]
    public init(workingDirectory: String? = nil, environment: [String: String] = [:]) {
        self.workingDirectory = workingDirectory; self.environment = environment
    }
    public static func parse(workingDirectory: String, environmentJSON: String) throws -> LaunchOptions {
        let variables: [String: String]
        do { variables = try JSONDecoder().decode([String: String].self, from: Data(environmentJSON.utf8)) }
        catch { throw CruzadorError.invalid("As variáveis devem ser um objeto JSON com nomes e valores de texto: \(error.localizedDescription)") }
        let options = LaunchOptions(workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory, environment: variables)
        try options.validate()
        return options
    }
    public func validate() throws {
        let reserved: Set<String> = ["WINEPREFIX", "WINESERVER", "WINELOADER", "WINEDLLPATH", "CX_BOTTLE", "CX_BOTTLE_PATH"]
        for (key, value) in environment {
            guard !key.isEmpty, !key.contains("="), !key.contains("\0"), !value.contains("\0") else { throw CruzadorError.invalid("Variável de ambiente inválida: \(key).") }
            guard !reserved.contains(key) else { throw CruzadorError.invalid("\(key) pertence à seleção do motor e da bottle. Escolha esses valores nas configurações.") }
        }
        if let workingDirectory {
            var directory: ObjCBool = false
            guard workingDirectory.hasPrefix("/"), !workingDirectory.contains("\0"), FileManager.default.fileExists(atPath: workingDirectory, isDirectory: &directory), directory.boolValue else {
                throw CruzadorError.invalid("A pasta de trabalho deve existir e ter um caminho absoluto: \(workingDirectory)")
            }
        }
    }
    public var environmentJSON: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(environment), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
public struct LaunchRequest: Equatable, Sendable {
    public var path: String
    public var arguments: [String]
    public var options: LaunchOptions
    public init(path: String, arguments: [String] = [], options: LaunchOptions = LaunchOptions()) {
        self.path = path; self.arguments = arguments; self.options = options
    }
    public func validate() throws {
        guard path.hasPrefix("/"), !path.contains("\0"), FileManager.default.isReadableFile(atPath: path), ["exe", "msi"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()), !arguments.contains(where: { $0.contains("\0") }) else {
            throw CruzadorError.invalid("Selecione um arquivo Windows existente (.exe ou .msi), com argumentos sem caracteres nulos.")
        }
        guard (try URL(fileURLWithPath: path).resolvingSymlinksInPath().resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else {
            throw CruzadorError.invalid("O programa selecionado deve ser um arquivo regular.")
        }
        try options.validate()
    }
}
