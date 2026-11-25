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
            machine = try WindowsPEHeader.machine(header: header, file: handle, size: size.uint64Value)
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

/// Shared owner of bounded PE header decoding for executable and DLL observations.
public enum WindowsPEHeader {
    public static func inspect(_ url: URL) throws -> UInt16 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else { throw CruzadorError.invalid("Tamanho do arquivo PE desconhecido.") }
        let file = try FileHandle(forReadingFrom: url); defer { try? file.close() }
        return try machine(header: file.read(upToCount: 64) ?? Data(), file: file, size: size.uint64Value)
    }
    static func machine(header: Data, file: FileHandle, size: UInt64) throws -> UInt16 {
        guard header.count >= 64, header.starts(with: [0x4d, 0x5a]) else { throw CruzadorError.invalid("Cabeçalho MZ inválido.") }
        let offset = (0..<4).reduce(UInt64(0)) { $0 | (UInt64(header[0x3c + $1]) << ($1 * 8)) }
        guard size >= 6, offset <= size - 6 else { throw CruzadorError.invalid("Cabeçalho PE fora dos limites do arquivo.") }
        try file.seek(toOffset: offset)
        let pe = try file.read(upToCount: 6) ?? Data()
        guard pe.count == 6, pe.starts(with: [0x50, 0x45, 0, 0]) else { throw CruzadorError.invalid("Assinatura PE não encontrada no arquivo.") }
        return UInt16(pe[4]) | UInt16(pe[5]) << 8
    }
}
