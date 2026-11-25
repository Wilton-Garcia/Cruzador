import Foundation

public enum BottleShell {
    /// Escape literal data for a POSIX/zsh word, including quotes and newlines.
    private static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    public static func prepare(bottle: Bottle, store: LibraryStore) throws -> URL {
        guard bottle.engine.kind != .crossOver, store.isReady(bottle) else { throw CruzadorError.invalid("O shell exige uma bottle pronta com Wine independente.") }
        let command = try EngineCommands.make(.tool(.commandPrompt), bottle: bottle, store: store).primary
        var environment = command.environment
        environment["CRUZADOR_WINE"] = command.executable.path
        environment["PATH"] = command.executable.deletingLastPathComponent().path + ":/usr/bin:/bin:/usr/sbin:/sbin"
        let assignments = environment.keys.sorted().map { quote($0 + "=" + environment[$0]!) }.joined(separator: " ")
        let directory = command.workingDirectory ?? store.prefix(for: bottle).appendingPathComponent("drive_c")
        let script = """
        #!/bin/zsh -f
        set -e
        cd -- \(quote(directory.path))
        printf '%s\\n' 'Cruzador — shell da bottle. Use "$CRUZADOR_WINE" para chamar o motor selecionado.'
        exec /usr/bin/env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" TMPDIR="$TMPDIR" TERM="$TERM" \(assignments) /bin/zsh -f

        """
        let root = store.root.appendingPathComponent("Shells"); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent(UUID().uuidString + ".command")
        try Data(script.utf8).write(to: file, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return file
    }
}
