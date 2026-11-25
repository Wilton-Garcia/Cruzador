import SwiftUI
import CruzadorCore

struct RetinaView: View {
    @ObservedObject var model: AppModel
    let bottle: Bottle
    @State private var selection: RetinaMode = .automatic
    @State private var observation = "Lendo registro…"
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Alta resolução — \(bottle.name)").font(.title2.bold())
            Text("Controla o modo Retina do driver macOS no Wine 11.21 incluído. Feche os programas da bottle antes de aplicar.").foregroundStyle(.secondary)
            Text(observation).textSelection(.enabled)
            Picker("Modo", selection: $selection) { ForEach(RetinaMode.allCases, id: \.self) { Text($0.displayName).tag($0) } }
            Text("A escolha é gravada no registro Wine e vale para novos processos. Nitidez, escala e compatibilidade dependem de cada aplicativo e monitor.").font(.caption).foregroundStyle(.secondary)
            if model.busy { ProgressView(model.status).progressViewStyle(.linear) }
            HStack {
                Button("Aplicar escolha") { model.applyRetina(selection, bottle: bottle) }.disabled(!model.canStart || model.presentation != .retina)
                Spacer()
                Button("Fechar") { model.dismissPresentation(.retina) }.disabled(model.busy).keyboardShortcut(.cancelAction)
            }
        }.padding(28).frame(width: 600).onAppear { refresh() }.onChange(of: model.busy) { if !model.busy { refresh() } }
    }
    private func refresh() {
        do { let saved = try RetinaConfiguration(store: model.store).saved(in: bottle); observation = saved.description; if let mode = saved.mode { selection = mode } }
        catch { observation = "Estado não verificado: " + error.localizedDescription }
    }
}
