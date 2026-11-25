import Foundation
import CryptoKit

public struct BottleDiagnostic: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let state: BottleState
    public let engine: Engine
    public let prefix: String
    public let prefixStatus: String
    public let prefixError: String?
    public let runtimeStatus: String
    public let runtimeManifest: WineRuntimeManifest?
    public let runtimeError: String?
    public let lastError: String?
    public let lastLogPath: String?
    public let appCount: Int
    public let installationCount: Int
}
public struct DiagnosticLog: Codable, Sendable {
    public let source: String
    public let status: String
    public let exportedPath: String?
    public let sha256: String?
    public let error: String?
}
public struct DiagnosticsReport: Codable, Sendable {
    public let formatVersion: Int
    public let capturedAt: Date
    public let macOS: String
    public let architecture: String
    public let libraryPath: String
    public let libraryStatus: String
    public let librarySHA256: String?
    public let libraryError: String?
    public let bottles: [BottleDiagnostic]?
    public let requestedBottleID: UUID?
    public var sourceLibraryRequested: Bool
    public var logsRequested: Bool
    public var sourceLibraryIncluded: Bool
    public var logsIncluded: Bool
    public var logs: [DiagnosticLog]
    public var warnings: [String]
    public let limitations: [String]
}
public struct DiagnosticsCapture: Sendable {
    public let report: DiagnosticsReport
    public let sourceLibrary: Data?
}
public struct DiagnosticsService: Sendable {
    public let store: LibraryStore
    public init(store: LibraryStore) { self.store = store }
    public func capture(bottleID: UUID? = nil) -> DiagnosticsCapture {
        var status: String, failure: String?, source: Data?, library: Library?
        do {
            switch try store.observe() {
            case .absent: status = "absent"; library = Library()
            case .valid(let parsed, let data): status = "valid"; library = parsed; source = data
            case .invalid(let data, let reason): status = "invalid"; source = data; failure = reason
            }
        } catch { status = "unreadable"; failure = error.localizedDescription }
        let bottles = library.map { library in
            library.bottles.filter { bottleID == nil || $0.id == bottleID }.map { bottle in
                let prefixStatus: String, prefixError: String?
                switch store.health(of: bottle) {
                case .absent: prefixStatus = "absent"; prefixError = nil
                case .incomplete: prefixStatus = "incomplete"; prefixError = nil
                case .initialized: prefixStatus = "initialized"; prefixError = nil
                case .unknown(let reason): prefixStatus = "unknown"; prefixError = reason
                }
                var manifest: WineRuntimeManifest?, runtimeError: String?
                let runtimeStatus: String
                if bottle.engine.kind == .packagedWine {
                    do { manifest = try WineRuntime(root: URL(fileURLWithPath: bottle.engine.path)).manifest; runtimeStatus = "manifest-validated" }
                    catch { runtimeStatus = "unavailable"; runtimeError = error.localizedDescription }
                } else { runtimeStatus = "external-not-inspected" }
                return BottleDiagnostic(id: bottle.id, name: bottle.name, state: bottle.state, engine: bottle.engine, prefix: store.prefix(for: bottle).path, prefixStatus: prefixStatus, prefixError: prefixError, runtimeStatus: runtimeStatus, runtimeManifest: manifest, runtimeError: runtimeError, lastError: bottle.lastError, lastLogPath: bottle.lastLogPath, appCount: bottle.apps.count, installationCount: bottle.installations?.count ?? 0)
            }
        }
        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x86_64"
        #else
        let architecture = "unknown"
        #endif
        var warnings: [String] = []
        if let bottleID, let library, !library.bottles.contains(where: { $0.id == bottleID }) { warnings.append("A bottle selecionada não existe na biblioteca: \(bottleID)") }
        let report = DiagnosticsReport(formatVersion: 1, capturedAt: Date(), macOS: ProcessInfo.processInfo.operatingSystemVersionString, architecture: architecture, libraryPath: store.manifest.path, libraryStatus: status, librarySHA256: source.map(Self.digest), libraryError: failure, bottles: bottles, requestedBottleID: bottleID, sourceLibraryRequested: false, logsRequested: false, sourceLibraryIncluded: false, logsIncluded: false, logs: [], warnings: warnings, limitations: ["Read-only metadata observation; no Windows code, process census or GPU test was executed.", "Manifest validation does not verify the full runtime inventory or binary behavior.", "Prefix readiness is structural and is separate from recorded preparation or shutdown completion.", "Log copies may span different instants; a copied-file digest describes the exported bytes.", "The ambient environment was not collected; optional source metadata and logs may contain caller-selected values and program output."])
        return DiagnosticsCapture(report: report, sourceLibrary: source)
    }
    public func export(to destination: URL, bottleID: UUID? = nil, includeSourceLibrary: Bool = false, includeLogs: Bool = false) throws -> URL {
        guard destination.isFileURL, !FileManager.default.fileExists(atPath: destination.path) else { throw CruzadorError.invalid("Escolha uma pasta de diagnóstico nova; o destino não será sobrescrito.") }
        let selected = destination.standardizedFileURL.resolvingSymlinksInPath().path
        let libraryRoot = store.root.resolvingSymlinksInPath().path
        guard selected != libraryRoot, !selected.hasPrefix(libraryRoot + "/") else { throw CruzadorError.invalid("Exporte o diagnóstico para fora da biblioteca para não copiar seu próprio pacote.") }
        let stage = destination.deletingLastPathComponent().appendingPathComponent(".cruzador-diagnostics-\(UUID())")
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        do {
            let capture = capture(bottleID: bottleID)
            var report = capture.report
            report.sourceLibraryRequested = includeSourceLibrary; report.logsRequested = includeLogs
            if includeSourceLibrary, let data = capture.sourceLibrary {
                try data.write(to: stage.appendingPathComponent("source-library.json"), options: .withoutOverwriting)
                report.sourceLibraryIncluded = true
            }
            if includeLogs { copyLogs(to: stage, report: &report) }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(report).write(to: stage.appendingPathComponent("report.json"), options: .withoutOverwriting)
            try FileManager.default.moveItem(at: stage, to: destination)
            return destination
        } catch { throw CruzadorError.invalid("Diagnóstico incompleto: \(error.localizedDescription). Arquivos preservados em \(stage.path).") }
    }
    private func copyLogs(to stage: URL, report: inout DiagnosticsReport) {
        do {
            let root = store.logsRoot
            guard try FileManager.default.attributesOfItem(atPath: root.path)[.type] as? FileAttributeType == .typeDirectory else { report.warnings.append("A pasta de logs não é um diretório regular; links não são seguidos: \(root.path)"); return }
            var warnings: [String] = []
            guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [], errorHandler: { url, error in warnings.append("\(url.path): \(error.localizedDescription)"); return true }) else { report.warnings.append("Não foi possível enumerar \(root.path)"); return }
            report.logsIncluded = true
            for case let file as URL in files {
                var output: String?
                var target: URL?
                do {
                    let type = try FileManager.default.attributesOfItem(atPath: file.path)[.type] as? FileAttributeType
                    if type == .typeDirectory { continue }
                    let canonicalFile = file.resolvingSymlinksInPath(), canonicalRoot = root.resolvingSymlinksInPath()
                    guard type == .typeRegular, canonicalFile.path.hasPrefix(canonicalRoot.path + "/") else {
                        files.skipDescendants()
                        report.logs.append(DiagnosticLog(source: file.path, status: "skipped", exportedPath: nil, sha256: nil, error: "Not a regular contained log file; links are not followed.")); continue
                    }
                    let relative = String(canonicalFile.path.dropFirst(canonicalRoot.path.count + 1))
                    let destination = stage.appendingPathComponent("Logs/" + relative)
                    output = "Logs/" + relative; target = destination
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: file, to: destination)
                    let handle = try FileHandle(forReadingFrom: destination); defer { try? handle.close() }
                    var hash = SHA256()
                    while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty { hash.update(data: chunk) }
                    let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
                    report.logs.append(DiagnosticLog(source: file.path, status: "copied", exportedPath: "Logs/" + relative, sha256: digest, error: nil))
                } catch {
                    let retained = target.flatMap { FileManager.default.fileExists(atPath: $0.path) ? output : nil }
                    report.logs.append(DiagnosticLog(source: file.path, status: "failed", exportedPath: retained, sha256: nil, error: error.localizedDescription))
                }
            }
            report.warnings += warnings
        } catch { report.warnings.append("\(store.logsRoot.path): \(error.localizedDescription)") }
    }
    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
