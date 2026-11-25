import Foundation

public enum WindowsFileKind: String, Codable, Sendable { case exe, msi }
public struct WindowsFileInspection: Codable, Sendable, Equatable {
    public let path: String
    public let kind: WindowsFileKind
    public let peMachine: UInt16?
    public let size: UInt64
    public let modificationDate: Date
    public static func inspect(path: String) throws -> WindowsFileInspection {
        try LaunchRequest(path: path).validate()
        let url = URL(fileURLWithPath: path)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, let modified = attributes[.modificationDate] as? Date else { throw CruzadorError.invalid("Não foi possível obter os metadados do arquivo Windows.") }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let header = try handle.read(upToCount: 64) ?? Data()
        guard let kind = WindowsFileKind(rawValue: url.pathExtension.lowercased()) else { throw CruzadorError.invalid("Formato de arquivo Windows não suportado.") }
        var machine: UInt16?
        switch kind {
        case .msi:
            guard header.starts(with: [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1]) else { throw CruzadorError.invalid("O arquivo .msi não tem a assinatura de armazenamento composto esperada.") }
        case .exe:
            guard header.count >= 64, header.starts(with: [0x4d, 0x5a]) else { throw CruzadorError.invalid("O arquivo .exe não tem um cabeçalho Windows válido.") }
            let offset = (0..<4).reduce(UInt64(0)) { $0 | (UInt64(header[0x3c + $1]) << ($1 * 8)) }
            guard size.uint64Value >= 6, offset <= size.uint64Value - 6 else { throw CruzadorError.invalid("Cabeçalho PE fora dos limites do arquivo.") }
            try handle.seek(toOffset: offset)
            let pe = try handle.read(upToCount: 6) ?? Data()
            guard pe.count == 6, pe.starts(with: [0x50, 0x45, 0, 0]) else { throw CruzadorError.invalid("Assinatura PE não encontrada no arquivo.") }
            machine = UInt16(pe[4]) | UInt16(pe[5]) << 8
        }
        return WindowsFileInspection(path: path, kind: kind, peMachine: machine, size: size.uint64Value, modificationDate: modified)
    }
    public func validateCurrentMetadata() throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        guard (attributes[.size] as? NSNumber)?.uint64Value == size, attributes[.modificationDate] as? Date == modificationDate else {
            throw CruzadorError.invalid("O arquivo Windows mudou depois de ser observado. Faça uma nova seleção ou busca.")
        }
    }
}
