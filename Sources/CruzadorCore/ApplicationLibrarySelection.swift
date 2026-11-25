import Foundation

/// Select a separate library for reproducible native UI checks without changing stored preferences.
public enum ApplicationLibrarySelection {
    public static func resolve(arguments: [String]) -> Result<URL?, CruzadorError> {
        let positions = arguments.indices.filter { arguments[$0] == "--library-root" }
        guard !positions.isEmpty else { return .success(nil) }
        guard positions.count == 1, let position = positions.first, position + 1 < arguments.count else { return .failure(.invalid("Use --library-root uma única vez, seguido de uma pasta absoluta.")) }
        let path = arguments[position + 1]
        guard path.hasPrefix("/"), !path.contains("\0") else { return .failure(.invalid("Pasta da biblioteca inválida: \(path). Informe um caminho absoluto após --library-root.")) }
        return .success(URL(fileURLWithPath: path, isDirectory: true))
    }
}
