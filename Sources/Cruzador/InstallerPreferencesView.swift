import AppKit
import SwiftUI
import CruzadorCore

struct InstallerPreferencesView: View {
    @ObservedObject var model: AppModel
    @State private var draft: InstallerPreferences
    init(model: AppModel) { self.model = model; _draft = State(initialValue: model.installerPreferences) }
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            Text("Instalação e cache").font(.title2.bold())
            if let problem = model.installerPreferenceProblem { Text("Preferências inválidas: \(problem). Salvar preservará uma cópia do arquivo anterior.").foregroundStyle(.red) }
            Picker("Modo padrão para MSI", selection: $draft.defaultMSIMode) { ForEach(InstallerMode.allCases, id: \.self) { Text($0.displayName).tag($0) } }
            Text("O assistente permite alterar o modo antes de instalar. EXEs e receitas mantêm os argumentos específicos de seu fornecedor ou catálogo.").font(.caption).foregroundStyle(.secondary)
            Picker("Downloads das receitas", selection: $draft.downloadPolicy) { ForEach(InstallerDownloadPolicy.allCases, id: \.self) { Text($0.displayName).tag($0) } }
            TextField("Pasta do cache; vazio usa o padrão", text: Binding(get: { draft.cacheDirectory ?? "" }, set: { draft.cacheDirectory = $0.isEmpty ? nil : $0 }))
            HStack {
                Button("Escolher pasta…") {
                    let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
                    if panel.runModal() == .OK { draft.cacheDirectory = panel.url?.path }
                }
                Button("Usar pasta padrão") { draft.cacheDirectory = nil }
            }
            Text("Padrão: \(model.store.root.appendingPathComponent("Downloads").path)").font(.caption).textSelection(.enabled)
            Button("Salvar preferências") { model.saveInstallerPreferences(draft) }.buttonStyle(.borderedProminent)
            Divider()
            Text(model.cacheStatus).font(.caption).textSelection(.enabled)
            HStack {
                Button("Inspecionar cache") { model.inspectInstallerCache() }
                Button("Limpar cache para a Lixeira…") { model.inspectInstallerCache(clear: true) }
            }.disabled(draft != model.installerPreferences || model.installerPreferenceProblem != nil)
            Text("Salve mudanças de pasta antes de inspecionar. A limpeza move somente arquivos reconhecidos por seus recibos; desconhecidos e downloads parciais são preservados. O SHA-256 do instalador é verificado ao reutilizá-lo.").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }.disabled(!model.canStart)
    }
}
