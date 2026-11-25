import Foundation

public struct WineRegistryValue: Codable, Sendable {
    public let name: String?
    public let string: String?
    public let type: String
    public let raw: String
    public let line: Int
}
public struct WineRegistryKey: Codable, Sendable {
    public let path: String
    public let line: Int
    public var values: [WineRegistryValue]
    public func string(named name: String) -> String? {
        let matches = values.filter { $0.name?.caseInsensitiveCompare(name) == .orderedSame }
        return matches.count == 1 ? matches[0].string : nil
    }
}
public struct WineRegistryDocument: Sendable {
    public let keys: [WineRegistryKey]
    public let warnings: [String]
    /// Reads selected keys of Wine's registry format 2. Unsupported value types
    /// retain their raw spelling; malformed values never become empty strings.
    public init(text: String, selecting: (String) -> Bool) {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        let header = lines.first.map { $0.hasPrefix("\u{feff}") ? String($0.dropFirst()) : $0 }
        guard header == "WINE REGISTRY Version 2" else {
            keys = []; warnings = ["Formato de registro Wine desconhecido."]; return
        }
        var parsed: [WineRegistryKey] = [], issues: [String] = [], current: WineRegistryKey?
        var cursor = 1
        while cursor < lines.count {
            let lineNumber = cursor + 1
            var line = lines[cursor]; cursor += 1
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") {
                if let current { parsed.append(current) }
                current = nil
                do {
                    let (path, _) = try Self.readString(Array(line.utf16), start: 1, delimiter: 0x5d)
                    if selecting(path) { current = WineRegistryKey(path: path, line: lineNumber, values: []) }
                } catch { issues.append("Chave inválida na linha \(lineNumber): \(error.localizedDescription)") }
                continue
            }
            guard current != nil else { continue }
            while line.hasSuffix("\\"), cursor < lines.count { line += "\n" + lines[cursor]; cursor += 1 }
            var parsedName: String?
            do {
                let units = Array(line.utf16)
                let name: String, afterName: Int
                if units.first == 0x40 { name = ""; afterName = 1 }
                else {
                    guard units.first == 0x22 else { throw CruzadorError.invalid("nome de valor esperado") }
                    (name, afterName) = try Self.readString(units, start: 1, delimiter: 0x22)
                }
                parsedName = name
                guard afterName < units.count, units[afterName] == 0x3d else { throw CruzadorError.invalid("separador de valor ausente") }
                let raw = String(decoding: units[(afterName + 1)...], as: UTF16.self)
                let value: String?, type: String
                if raw.hasPrefix("\"") {
                    let (decoded, end) = try Self.readString(Array(raw.utf16), start: 1, delimiter: 0x22)
                    guard end == raw.utf16.count else { throw CruzadorError.invalid("conteúdo depois da string") }
                    value = decoded; type = "string"
                } else if raw.hasPrefix("str(2):\"") {
                    let (decoded, end) = try Self.readString(Array(raw.utf16), start: 8, delimiter: 0x22)
                    guard end == raw.utf16.count else { throw CruzadorError.invalid("conteúdo depois da string expandida") }
                    value = decoded; type = "expand-string-unexpanded"
                } else { value = nil; type = "unsupported" }
                if current?.values.contains(where: { $0.name?.caseInsensitiveCompare(name) == .orderedSame }) == true {
                    issues.append("Valor duplicado na linha \(lineNumber): \(name). Sua interpretação permanece desconhecida.")
                }
                current?.values.append(WineRegistryValue(name: name, string: value, type: type, raw: raw, line: lineNumber))
            } catch {
                current?.values.append(WineRegistryValue(name: parsedName, string: nil, type: "malformed", raw: line, line: lineNumber))
                issues.append("Valor inválido na linha \(lineNumber): \(error.localizedDescription)")
            }
        }
        if let current { parsed.append(current) }
        keys = parsed; warnings = issues
    }
    private static func readString(_ input: [UInt16], start: Int, delimiter: UInt16) throws -> (String, Int) {
        var output: [UInt16] = [], index = start
        func digit(_ unit: UInt16, radix: UInt16) -> UInt16? {
            let value: UInt16
            switch unit { case 48...57: value = unit - 48; case 65...70: value = unit - 65 + 10; case 97...102: value = unit - 97 + 10; default: return nil }
            return value < radix ? value : nil
        }
        let escapes: [UInt16: UInt16] = [97: 7, 98: 8, 101: 27, 102: 12, 110: 10, 114: 13, 116: 9, 118: 11]
        while index < input.count {
            var unit = input[index]; index += 1
            if unit == delimiter {
                let decoded = String(decoding: output, as: UTF16.self)
                guard Array(decoded.utf16) == output else { throw CruzadorError.invalid("Unicode incompleto") }
                return (decoded, index)
            }
            if unit == 92 {
                guard index < input.count else { throw CruzadorError.invalid("escape incompleto") }
                unit = input[index]; index += 1
                if let escaped = escapes[unit] { output.append(escaped); continue }
                let radix: UInt16 = unit == 120 ? 16 : 8
                if unit == 120 || digit(unit, radix: 8) != nil {
                    var value: UInt16 = 0, count = 0
                    if unit != 120 { value = unit - 48; count = 1 }
                    while index < input.count, count < (radix == 16 ? 4 : 3), let next = digit(input[index], radix: radix) {
                        value = value * radix + next; index += 1; count += 1
                    }
                    if count == 0 { output.append(120) } else { output.append(value) }
                    continue
                }
            }
            output.append(unit)
        }
        throw CruzadorError.invalid("delimitador ausente")
    }
}
