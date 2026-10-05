pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string user: Quickshell.env("USER") || "dd"
    readonly property string kitty: "/etc/profiles/per-user/" + root.user + "/bin/kitty"
    readonly property string bash: "/run/current-system/sw/bin/bash"
    // Inline rebuild so the button works before the new aurora package is switched in
    // (chicken-and-egg: aurora update only exists after a successful rebuild).
    readonly property string script: "repo=\"$HOME/Documents/projects/config\"; cd \"$repo\" || { echo \"Could not open $repo\"; read -r _; exit 1; }; before=$(git rev-parse --short HEAD 2>/dev/null || echo unknown); echo \"==> git pull --ff-only\"; if git pull --ff-only; then after=$(git rev-parse --short HEAD 2>/dev/null || echo unknown); if [ \"$before\" = \"$after\" ]; then pull=\"Already up to date ($after).\"; else pull=\"Pulled $before → $after.\"; fi; else pull=\"Git pull skipped (could not fast-forward).\"; echo; echo \"$pull\"; fi; echo; echo \"==> nixos-rebuild switch --flake $repo#nixos\"; if sudo nixos-rebuild switch --flake \"$repo#nixos\"; then echo; echo Done.; notify-send -a Aurora -u normal -- \"System update\" \"$pull Rebuild finished.\" 2>/dev/null || true; else echo; echo Rebuild failed.; notify-send -a Aurora -u critical -- \"System update\" \"$pull Rebuild failed.\" 2>/dev/null || true; fi; echo; printf 'Press enter to close.\\n'; read -r _"
    property bool running: false

    function start() {
        if (root.running || proc.running)
            return;
        proc.running = true;
    }

    property Process proc: Process {
        // kitty has no -e; program args follow options directly.
        command: [root.kitty, "--class", "sysupdate", root.bash, "-lc", root.script]
        running: false
        onRunningChanged: root.running = running
    }
}
