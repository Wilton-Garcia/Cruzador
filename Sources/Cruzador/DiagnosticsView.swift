import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var model: AppModel
    @State private var includeSourceLibrary = false
    @State private var includeLogs = false
    @State private var selectedBottleOnly = true
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Diagnóstico local").font(.title2.bold())
            Text("O relatório descreve o sistema, a biblioteca e os motores, incluindo falhas de leitura. Não executa programas Windows nem envia dados.")
            if let bottle = model.selected { Toggle("Relatório somente de \(bottle.name)", isOn: $selectedBottleOnly) }
            Toggle("Incluir cópia exata de library.json", isOn: $includeSourceLibrary)
            Text("A cópia inclui toda a biblioteca, caminhos, argumentos e variáveis explicitamente salvas, inclusive quando o arquivo está inválido.").font(.caption).foregroundStyle(.secondary)
            Toggle("Incluir arquivos da pasta Logs (todas as bottles)", isOn: $includeLogs)
            Text("Logs podem conter saída dos programas e valores privados. Links para arquivos externos não são seguidos. Revise o pacote antes de compartilhá-lo.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Fechar") { model.dismissPresentation(.diagnostics) }.keyboardShortcut(.cancelAction).disabled(model.busy)
                Spacer()
                Button("Exportar diagnóstico…") { model.exportDiagnostics(includeSourceLibrary: includeSourceLibrary, includeLogs: includeLogs, selectedBottleOnly: selectedBottleOnly && model.selected != nil) }.buttonStyle(.borderedProminent).disabled(model.busy)
            }
        }.padding(28).frame(width: 580)
    }
}
