import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CruzadorCore

@MainActor
final class AppModel: ObservableObject {
    @Published var library = Library()
    @Published var selection: UUID?
    @Published var busy = false
    @Published var cancelling = false
    @Published var cleanupOperationID: UUID?
    private var activeOperationID: UUID?
    @Published var status = "Sua biblioteca Windows no Mac"
    @Published var error: String?
    @Published var lastLog: URL?
    @Published var showCreate = false
    @Published var showRegister = false
    @Published var editingApp: WindowsApp?
    @Published var showInstall = false
    @Published var selectedInstaller: InstallerInspection?
    @Published var showRecipes = false
    @Published var recipeCatalog: RecipeCatalog?
    private var recipeTask: Task<Void, Never>?
    @Published var search = ""
    @Published var engineKind: EngineKind = .packagedWine
    @Published var enginePath = WineRuntime.bundledRoot.path
    private var enginePreferenceError: String?
    @Published var loaded = false
    let store = LibraryStore(root: LibraryStore.defaultRoot)
    private let runner = CommandRunner()
    var canStart: Bool { !busy && cleanupOperationID == nil }
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
            try InstallationService(store: store).recoverInterrupted()
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
        guard !name.isEmpty, loaded, canStart else { return }
        do {
            if let enginePreferenceError { throw CruzadorError.invalid(enginePreferenceError) }
            let bottle = try BottleLifecycle(store: store).create(name: name, engine: Engine(kind: engineKind, path: enginePath))
            library = try store.load()
            selection = bottle.id; showCreate = false
            perform(.initialize, bottle: bottle, title: "Preparando \(name)…")
        } catch { self.error = error.localizedDescription }
    }
    func perform(_ action: BottleAction, bottle: Bottle, title: String) {
        guard loaded, canStart else { return }
        do {
            switch action {
            case .initialize, .repair: break
            default:
                guard store.isReady(bottle) else { throw CruzadorError.invalid("A bottle ainda não está pronta. Use Preparar novamente ou consulte o log.") }
            }
            let command: EnginePlan?
            switch action {
            case .initialize, .repair, .install: command = nil
            default: command = try EngineCommands.make(action, bottle: bottle, store: store)
            }
            let log = store.logsRoot.appendingPathComponent("\(Date().timeIntervalSince1970)-\(UUID().uuidString).log")
            let operationID = UUID()
            activeOperationID = operationID; cancelling = false
            busy = true; status = title; lastLog = log
            Task {
                defer { busy = false; activeOperationID = nil; cancelling = false }
                do {
                    let result: RunResult
                    switch action {
                    case .initialize, .repair:
                        result = try await BottleLifecycle(store: store).prepare(id: bottle.id, mode: {
                            if case .repair = action { return .repair }; return .initialize
                        }(), runner: runner, log: log, operationID: operationID)
                        library = try store.load()
                    case .install(let request):
                        result = try await InstallationService(store: store).run(request, bottle: bottle, runner: runner, log: log, operationID: operationID)
                        library = try store.load()
                    default:
                        guard let command else { throw CruzadorError.invalid("Plano de execução ausente.") }
                        result = try await runner.run(command, log: log, operationID: operationID)
                    }
                    try result.requireSuccess()
                    status = "Operação concluída"
                } catch {
                    status = "Operação não concluída"
                    if let failure = error as? CommandRunnerError, failure.requiresBottleDiagnosis {
                        cleanupOperationID = operationID
                        do {
                            var next = try store.load()
                            if let index = next.bottles.firstIndex(where: { $0.id == bottle.id }) {
                                next.bottles[index].state = .interrupted; next.bottles[index].lastError = failure.localizedDescription
                            }
                            try persist(next)
                        } catch { self.error = "Falha ao preservar o estado: \(error.localizedDescription)"; return }
                    }
                    do { library = try store.load() }
                    catch { self.error = "Não foi possível reler a biblioteca: \(error.localizedDescription)"; return }
                    self.error = error.localizedDescription
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    func chooseProgram(installer: Bool = false) {
        guard let bottle = selected, canStart else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false
        panel.allowedContentTypes = ["exe", "msi"].compactMap { UTType(filenameExtension: $0) }
        panel.message = installer ? "Escolha o instalador Windows" : "Escolha o executável Windows"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if installer {
            do { selectedInstaller = try InstallerInspection.inspect(path: url.path); showInstall = true }
            catch { self.error = error.localizedDescription }
        } else { perform(.run(LaunchRequest(path: url.path)), bottle: bottle, title: "Executando programa…") }
    }
    func installSelected(mode: InstallerMode, arguments: String, workingDirectory: String, environmentJSON: String) {
        guard let inspection = selectedInstaller, let bottle = selected, canStart else { return }
        do {
            let options = try LaunchOptions.parse(workingDirectory: workingDirectory, environmentJSON: environmentJSON)
            let request = try InstallationRequest(inspection: inspection, mode: mode, arguments: arguments.isEmpty ? [] : arguments.components(separatedBy: "\n"), options: options)
            showInstall = false
            perform(.install(request), bottle: bottle, title: "Instalando \(URL(fileURLWithPath: inspection.path).lastPathComponent)…")
        } catch { self.error = error.localizedDescription }
    }
    func openRecipes() {
        guard canStart else { return }
        do { recipeCatalog = try RecipeCatalog(data: Data(contentsOf: RecipeCatalog.bundledURL)); showRecipes = true }
        catch { self.error = "Não foi possível abrir o catálogo incluído: \(error.localizedDescription)" }
    }
    func installRecipe(id: String, catalog: RecipeCatalog) {
        guard let bottle = selected, store.isReady(bottle), canStart else { return }
        let operationID = UUID()
        let service = RecipeInstallationService(store: store, runner: runner, cache: ArtifactCache(root: store.root.appendingPathComponent("Downloads")), operationID: operationID)
        showRecipes = false; busy = true; cancelling = false; activeOperationID = operationID
        status = "Preparando receita…"
        recipeTask = Task {
            defer { busy = false; cancelling = false; activeOperationID = nil; recipeTask = nil }
            do {
                _ = try await service.install(id: id, bottleID: bottle.id, catalog: catalog) { message in
                    await MainActor.run { if self.activeOperationID == operationID { self.status = message } }
                }
                library = try store.load()
                lastLog = library.bottles.first(where: { $0.id == bottle.id })?.installations?.last.map { URL(fileURLWithPath: $0.logPath) }
                status = "Receita concluída; atalhos verificados"
            } catch {
                if let failure = error as? CommandRunnerError, failure.requiresBottleDiagnosis { cleanupOperationID = operationID }
                do {
                    library = try store.load()
                    lastLog = library.bottles.first(where: { $0.id == bottle.id })?.installations?.last.map { URL(fileURLWithPath: $0.logPath) }
                } catch { self.error = error.localizedDescription; return }
                self.error = error.localizedDescription; status = "Receita não concluída"
            }
        }
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
        guard loaded, canStart else { return }
        busy = true; status = title; cancelling = false
        let service = BottleMaintenance(store: store, runner: runner)
        activeOperationID = service.operationID
        Task {
            defer { busy = false; activeOperationID = nil; cancelling = false }
            do {
                let selectedID = try await operation(service)
                library = try store.load()
                selection = selectedID ?? library.bottles.first?.id
                status = "Operação concluída"
            } catch {
                status = "Operação não concluída"
                if let failure = error as? CommandRunnerError, failure.requiresBottleDiagnosis { cleanupOperationID = service.operationID }
                self.error = error.localizedDescription
            }
        }
    }
    func cancelCurrentOperation() {
        guard let operationID = activeOperationID, busy, !cancelling else { return }
        cancelling = true; status = "Solicitando encerramento…"
        let recipe = recipeTask
        Task {
            let accepted = await runner.cancel(operationID: operationID)
            recipe?.cancel()
            if activeOperationID == operationID {
                status = accepted || recipe != nil ? "Aguardando encerramento e limpeza…" : "A fase atual não tem processo cancelável. Aguarde sua conclusão."
                if !accepted && recipe == nil { cancelling = false }
            }
        }
    }
    func retryCleanup() {
        guard let failedID = cleanupOperationID, !busy else { return }
        let operationID = UUID(); activeOperationID = operationID; busy = true; cancelling = false
        status = "Repetindo encerramento…"
        Task {
            defer { busy = false; activeOperationID = nil; cancelling = false }
            do {
                let result = try await runner.retryCleanup(failedOperationID: failedID, operationID: operationID)
                lastLog = result.log; cleanupOperationID = nil
                status = "Encerramento concluído. Prepare a bottle novamente antes de retomar."
            } catch { self.error = error.localizedDescription; status = "Encerramento não confirmado" }
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
