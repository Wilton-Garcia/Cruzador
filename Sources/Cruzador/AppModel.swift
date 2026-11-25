import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CruzadorCore

@MainActor
final class AppModel: ObservableObject {
    @Published var library = Library()
    @Published var selection: UUID?
    @Published var busy = false
    @Published var status = "Sua biblioteca Windows no Mac"
    @Published var error: String?
    @Published var lastLog: URL?
    @Published var showCreate = false
    @Published var showRegister = false
    @Published var editingApp: WindowsApp?
    @Published var search = ""
    @Published var engineKind: EngineKind = .packagedWine
    @Published var enginePath = WineRuntime.bundledRoot.path
    private var enginePreferenceError: String?
    @Published var loaded = false
    let store = LibraryStore(root: LibraryStore.defaultRoot)
    private let runner = CommandRunner()
    var selected: Bottle? { library.bottles.first { $0.id == selection } }
    var filteredBottles: [Bottle] { library.bottles.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) } }
    init() {
        do {
            let engine = try EnginePreferences.load(from: .standard)
            engineKind = engine.kind; enginePath = engine.path
        } catch { enginePreferenceError = error.localizedDescription }
        do {
            try store.migrateIfNeeded()
            try BottleLifecycle(store: store).recoverInterruptedPreparations()
        }
        catch { self.error = error.localizedDescription }
        reload()
        if let enginePreferenceError { error = enginePreferenceError }
    }
    func reload() {
        guard !busy else { return }
        do {
            library = try store.load(); loaded = true
            if selection == nil { selection = library.preferences.defaultBottleID ?? library.bottles.first?.id }
        } catch { loaded = false; self.error = "Não foi possível abrir a biblioteca: \(error.localizedDescription)" }
    }
    func saveEngine() {
        do {
            try EnginePreferences.save(Engine(kind: engineKind, path: enginePath), to: .standard)
            enginePreferenceError = nil
        } catch { self.error = error.localizedDescription }
    }
    func selectEngine(_ kind: EngineKind) {
        engineKind = kind
        enginePath = kind == .packagedWine ? WineRuntime.bundledRoot.path : ""
    }
    private func persist(_ next: Library) throws { try store.save(next); library = next }
    func create(name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, loaded, !busy else { return }
        do {
            if let enginePreferenceError { throw CruzadorError.invalid(enginePreferenceError) }
            let bottle = try BottleLifecycle(store: store).create(name: name, engine: Engine(kind: engineKind, path: enginePath))
            library = try store.load()
            selection = bottle.id; showCreate = false
            perform(.initialize, bottle: bottle, title: "Preparando \(name)…")
        } catch { self.error = error.localizedDescription }
    }
    func perform(_ action: BottleAction, bottle: Bottle, title: String) {
        guard loaded, !busy else { return }
        do {
            switch action {
            case .initialize, .repair: break
            default:
                guard bottle.state == .ready, store.isInitialized(bottle) else { throw CruzadorError.invalid("A bottle ainda não está pronta. Use Preparar novamente ou consulte o log.") }
            }
            let command: EnginePlan?
            switch action {
            case .initialize, .repair: command = nil
            default: command = try EngineCommands.make(action, bottle: bottle, store: store)
            }
            let log = store.logsRoot.appendingPathComponent("\(Date().timeIntervalSince1970)-\(UUID().uuidString).log")
            busy = true; status = title; lastLog = log
            Task {
                defer { busy = false }
                do {
                    let result: RunResult
                    switch action {
                    case .initialize, .repair:
                        result = try await BottleLifecycle(store: store).prepare(id: bottle.id, mode: {
                            if case .repair = action { return .repair }; return .initialize
                        }(), runner: runner, log: log)
                        library = try store.load()
                    default:
                        guard let command else { throw CruzadorError.invalid("Plano de execução ausente.") }
                        result = try await runner.run(command, log: log)
                    }
                    guard result.exitCode == 0 else { throw CruzadorError.invalid("O motor terminou com código \(result.exitCode). Consulte o log para os detalhes.") }
                    status = "Operação concluída"
                } catch {
                    status = "Operação não concluída"
                    do { library = try store.load() }
                    catch { self.error = "Não foi possível reler a biblioteca: \(error.localizedDescription)"; return }
                    self.error = error.localizedDescription
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func chooseProgram(installer: Bool = false) {
        guard let bottle = selected, !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false
        panel.allowedContentTypes = ["exe", "msi"].compactMap { UTType(filenameExtension: $0) }
        panel.message = installer ? "Escolha o instalador Windows" : "Escolha o executável Windows"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform(installer ? .install(url.path) : .run(LaunchRequest(path: url.path)), bottle: bottle, title: installer ? "Instalando programa…" : "Executando programa…")
    }
    func beginRegister(_ app: WindowsApp? = nil) { editingApp = app; showRegister = true }
    func register(name: String, path: String, arguments: String, workingDirectory: String, environmentJSON: String) {
        guard let selected, !busy else { return }
        do {
            let options = try LaunchOptions.parse(workingDirectory: workingDirectory, environmentJSON: environmentJSON)
            let request = LaunchRequest(path: path, arguments: arguments.isEmpty ? [] : arguments.components(separatedBy: "\n"), options: options)
            try request.validate()
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw CruzadorError.invalid("Informe um nome para o aplicativo.") }
            var next = library
            guard let index = next.bottles.firstIndex(where: { $0.id == selected.id }) else { return }
            var app = WindowsApp(name: name, path: path, arguments: request.arguments, options: options)
            if let editingApp {
                guard let appIndex = next.bottles[index].apps.firstIndex(where: { $0.id == editingApp.id }) else { throw CruzadorError.invalid("O atalho não existe mais nesta bottle.") }
                app.id = editingApp.id; next.bottles[index].apps[appIndex] = app
            } else { next.bottles[index].apps.append(app) }
            try persist(next); showRegister = false
        } catch { self.error = error.localizedDescription }
    }
    func removeShortcut(_ app: WindowsApp, bottle: Bottle) {
        guard !busy else { return }
        do {
            var next = library
            guard let index = next.bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
            next.bottles[index].apps.removeAll { $0.id == app.id }; try persist(next)
        } catch { self.error = error.localizedDescription }
    }
    private func maintenance(_ title: String, operation: @escaping @Sendable (BottleMaintenance) async throws -> UUID?) {
        guard loaded, !busy else { return }
        busy = true; status = title
        let service = BottleMaintenance(store: store, runner: runner)
        Task {
            defer { busy = false }
            do {
                let selectedID = try await operation(service)
                library = try store.load()
                selection = selectedID ?? library.bottles.first?.id
                status = "Operação concluída"
            } catch {
                status = "Operação não concluída"
                self.error = error.localizedDescription
            }
        }
    }
    func makeDefault(_ bottle: Bottle) {
        guard !busy else { return }
        do {
            var next = library; next.preferences.defaultBottleID = bottle.id
            try persist(next); status = "Bottle padrão: \(bottle.name)"
        } catch { self.error = error.localizedDescription }
    }
    func nameBottle(_ bottle: Bottle, duplicate: Bool) {
        guard !busy else { return }
        let alert = NSAlert(); alert.messageText = duplicate ? "Duplicar bottle" : "Renomear bottle"
        let field = NSTextField(string: duplicate ? bottle.name + " — cópia" : bottle.name)
        field.frame = NSRect(x: 0, y: 0, width: 320, height: 24); alert.accessoryView = field
        alert.addButton(withTitle: duplicate ? "Duplicar" : "Renomear"); alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue
        maintenance(duplicate ? "Copiando bottle…" : "Renomeando bottle…") { service in
            if duplicate { return try await service.duplicate(id: bottle.id, name: name).id }
            try service.rename(id: bottle.id, name: name); return bottle.id
        }
    }
    func exportBottle(_ bottle: Bottle) {
        guard !busy else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = bottle.name + ".cruzadorbottle"
        panel.message = "Escolha um novo pacote. Feche os programas Windows antes de exportar."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        maintenance("Exportando bottle…") { service in
            try await service.export(id: bottle.id, destination: destination); return bottle.id
        }
    }
    func importBottle() {
        guard !busy else { return }
        if let enginePreferenceError { error = enginePreferenceError; return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        panel.message = "Selecione a pasta .cruzadorbottle que contém bottle.json e Prefix. Ela será copiada e usará o motor selecionado nas configurações."
        guard panel.runModal() == .OK, let source = panel.url else { return }
        let engine = Engine(kind: engineKind, path: enginePath)
        maintenance("Importando bottle…") { service in try service.importBottle(from: source, engine: engine).id }
    }
    func removeBottle(_ bottle: Bottle) {
        guard !busy else { return }
        let alert = NSAlert(); alert.messageText = "Remover \(bottle.name) da biblioteca?"
        alert.informativeText = "Feche os programas Windows. Os arquivos serão movidos para a pasta Removed da biblioteca e poderão ser importados novamente."
        alert.addButton(withTitle: "Remover e preservar cópia"); alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        maintenance("Removendo bottle…") { service in _ = try await service.remove(id: bottle.id); return nil }
    }

}
