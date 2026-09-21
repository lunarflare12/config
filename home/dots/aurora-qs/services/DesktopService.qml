pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string desktopPath: root.home + "/Desktop"

    property var items: []
    property var selected: []
    property string renaming: ""
    property string error: ""

    readonly property int count: root.items.length
    readonly property int selectedCount: root.selected.length

    function isSelected(path) {
        return root.selected.indexOf(path) !== -1;
    }

    function clearSelection() {
        root.selected = [];
        root.renaming = "";
    }

    function selectOnly(path) {
        root.selected = path ? [path] : [];
        if (root.renaming !== path)
            root.renaming = "";
    }

    function toggleSelect(path) {
        const next = root.selected.slice();
        const i = next.indexOf(path);
        if (i === -1)
            next.push(path);
        else
            next.splice(i, 1);
        root.selected = next;
        root.renaming = "";
    }

    function selectPaths(paths) {
        root.selected = paths.slice();
        root.renaming = "";
    }

    function selectAll() {
        const paths = [];
        for (let i = 0; i < root.items.length; i++)
            paths.push(root.items[i].path);
        root.selected = paths;
        root.renaming = "";
    }

    function uniqueName(base, ext) {
        const names = {};
        for (let i = 0; i < root.items.length; i++)
            names[root.items[i].name] = true;
        const first = base + ext;
        if (!names[first])
            return first;
        for (let n = 2; n < 200; n++) {
            const cand = base + " " + n + ext;
            if (!names[cand])
                return cand;
        }
        return base + " " + Date.now() + ext;
    }

    function gameIcon(item) {
        const blob = [
            item && item.name ? item.name : "",
            item && item.desktopIcon ? item.desktopIcon : "",
            item && item.path ? item.path : ""
        ].join(" ").toLowerCase();

        if (blob.indexOf("terraria") !== -1 || blob.indexOf("105600") !== -1)
            return "file://" + Quickshell.shellDir + "/assets/games/terraria.png";
        return "";
    }

    function iconSource(item) {
        if (!item)
            return Quickshell.iconPath("text-x-generic");
        if (item.preview)
            return item.preview;
        if (item.isDir)
            return Quickshell.iconPath("folder", "inode-directory");

        const game = root.gameIcon(item);
        if (game)
            return game;

        const name = String(item.name || "").toLowerCase();
        if (name.endsWith(".desktop")) {
            const iconName = String(item.desktopIcon || name.slice(0, -8));
            if ((iconName + " " + name).toLowerCase().indexOf("kitty") !== -1)
                return "file://" + Quickshell.shellDir + "/assets/kitty.png";
            return Quickshell.iconPath(iconName, "application-x-executable");
        }

        return Quickshell.iconPath(item.mimeIcon || "text-x-generic", "text-x-generic");
    }

    function displayName(item) {
        if (!item)
            return "";
        const name = String(item.name || "");
        if (name.toLowerCase().endsWith(".desktop"))
            return name.slice(0, -8);
        return name;
    }

    function itemByPath(path) {
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].path === path)
                return root.items[i];
        }
        return null;
    }

    function refresh() {
        if (!scanProcess.running)
            scanProcess.running = true;
    }

    function beginRename(path) {
        if (!path)
            return;
        root.selected = [path];
        root.renaming = path;
    }

    function tokenize(cmd) {
        const out = [];
        let cur = "";
        let quote = "";
        const text = String(cmd || "");
        for (let i = 0; i < text.length; i++) {
            const ch = text.charAt(i);
            if (quote) {
                if (ch === quote)
                    quote = "";
                else
                    cur += ch;
                continue;
            }
            if (ch === "\"" || ch === "'") {
                quote = ch;
                continue;
            }
            if (ch === " " || ch === "\t") {
                if (cur.length) {
                    out.push(cur);
                    cur = "";
                }
                continue;
            }
            cur += ch;
        }
        if (cur.length)
            out.push(cur);
        return out;
    }

    function open(path) {
        if (!path)
            return;

        const item = root.itemByPath(path);
        const desktop = (item && String(item.name || "").toLowerCase().endsWith(".desktop")) || String(path).toLowerCase().endsWith(".desktop");
        if (desktop) {
            let exec = item && item.exec ? String(item.exec) : "";
            exec = exec.replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
            const argv = root.tokenize(exec);
            if (argv.length) {
                Quickshell.execDetached(argv);
                return;
            }
            Quickshell.execDetached(["gio", "launch", path]);
            return;
        }

        Quickshell.execDetached(["xdg-open", path]);
    }

    function openDesktop() {
        Quickshell.execDetached([root.home + "/.config/scripts/finder.sh", root.desktopPath]);
    }

    function createFolder() {
        const name = root.uniqueName("Untitled Folder", "");
        const path = root.desktopPath + "/" + name;
        Quickshell.execDetached(["mkdir", "-p", path]);
        root.selected = [path];
        root.renaming = path;
        Qt.callLater(root.refresh);
        refreshTimer.restart();
    }

    function createFile() {
        const name = root.uniqueName("Untitled", ".txt");
        const path = root.desktopPath + "/" + name;
        Quickshell.execDetached(["touch", path]);
        root.selected = [path];
        root.renaming = path;
        Qt.callLater(root.refresh);
        refreshTimer.restart();
    }

    function rename(path, name) {
        const clean = String(name || "").replace(/\//g, "").trim();
        root.renaming = "";
        if (!path || !clean)
            return;
        const item = root.itemByPath(path);
        if (!item || item.name === clean)
            return;
        const dest = root.desktopPath + "/" + clean;
        Quickshell.execDetached(["mv", "-n", path, dest]);
        root.selected = [dest];
        refreshTimer.restart();
    }

    function trashSelected() {
        const paths = root.selected.slice();
        if (paths.length === 0)
            return;
        Quickshell.execDetached(["sh", "-c", "if command -v gio >/dev/null 2>&1; then gio trash -- \"$@\"; else rm -rf -- \"$@\"; fi", "trash"].concat(paths));
        root.clearSelection();
        refreshTimer.restart();
        trashTimer.restart();
    }

    property bool trashFull: false

    readonly property string trashIcon: Quickshell.iconPath(root.trashFull ? "user-trash-full" : "user-trash", "user-trash")

    function openTrash() {
        Quickshell.execDetached([
            "sh",
            "-c",
            "mkdir -p \"$HOME/.local/share/Trash/files\" \"$HOME/.local/share/Trash/info\"; fm=\"$HOME/.config/scripts/finder.sh\"; if gio list trash:// >/dev/null 2>&1; then exec \"$fm\" trash:///; fi; exec \"$fm\" \"$HOME/.local/share/Trash/files\""
        ]);
    }

    function emptyTrash() {
        if (!root.trashFull)
            return;
        Quickshell.execDetached([
            "sh",
            "-c",
            "if gio trash --empty >/dev/null 2>&1; then exit 0; fi; rm -rf \"$HOME/.local/share/Trash/files\" \"$HOME/.local/share/Trash/info\"; mkdir -p \"$HOME/.local/share/Trash/files\" \"$HOME/.local/share/Trash/info\""
        ]);
        root.trashFull = false;
        trashTimer.restart();
    }

    function ingest(text) {
        if (!text) {
            root.items = [];
            return;
        }

        const lines = text.split("\n");
        const out = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (!line || line.trim().length === 0)
                continue;

            const tab = line.indexOf("\t");
            if (tab <= 0)
                continue;

            const kind = line.substring(0, tab);
            const rest = line.substring(tab + 1);
            const tab2 = rest.indexOf("\t");
            if (tab2 <= 0)
                continue;

            const name = rest.substring(0, tab2);
            const tail = rest.substring(tab2 + 1);
            const tab3 = tail.indexOf("\t");
            const path = tab3 >= 0 ? tail.substring(0, tab3) : tail;
            const meta = tab3 >= 0 ? tail.substring(tab3 + 1) : "";
            const tab4 = meta.indexOf("\t");
            const desktopIcon = tab4 >= 0 ? meta.substring(0, tab4) : meta;
            const exec = tab4 >= 0 ? meta.substring(tab4 + 1) : "";
            const lower = name.toLowerCase();
            const isDir = kind === "d";
            let mimeIcon = "text-x-generic";
            let preview = "";
            if (isDir) {
                mimeIcon = "folder";
            } else if (lower.match(/\.(png|jpe?g|gif|webp|bmp|svg)$/)) {
                mimeIcon = "image-x-generic";
                preview = "file://" + path;
            } else if (lower.match(/\.(mp4|mkv|webm|mov|avi)$/)) {
                mimeIcon = "video-x-generic";
            } else if (lower.match(/\.(mp3|flac|wav|ogg|m4a)$/)) {
                mimeIcon = "audio-x-generic";
            } else if (lower.endsWith(".pdf")) {
                mimeIcon = "application-pdf";
            } else if (lower.match(/\.(zip|tar|gz|tgz|7z|rar|xz)$/)) {
                mimeIcon = "package-x-generic";
            } else if (lower.match(/\.(txt|md|log|csv)$/)) {
                mimeIcon = "text-x-generic";
            } else if (lower.match(/\.(sh|bash|py|js|ts|nix|c|cpp|rs|go)$/)) {
                mimeIcon = "text-x-script";
            } else if (lower.endsWith(".desktop")) {
                mimeIcon = "application-x-executable";
            }

            out.push({
                "name": name,
                "path": path,
                "isDir": isDir,
                "mimeIcon": mimeIcon,
                "preview": preview,
                "desktopIcon": desktopIcon,
                "exec": exec
            });
        }

        root.items = out;
    }

    property Process scanProcess: Process {
        command: [
            "sh",
            "-c",
            "mkdir -p \"$1\" && find \"$1\" -mindepth 1 -maxdepth 1 ! -name '.*' -print0 | while IFS= read -r -d '' p; do n=${p##*/}; if [ -d \"$p\" ]; then printf 'd\\t%s\\t%s\\t\\t\\n' \"$n\" \"$p\"; else icon=; exec=; case \"$n\" in *.desktop) icon=$(awk -F= '/^Icon=/{print substr($0, index($0, \"=\")+1); exit}' \"$p\"); exec=$(awk -F= '/^Exec=/{print substr($0, index($0, \"=\")+1); exit}' \"$p\");; esac; printf 'f\\t%s\\t%s\\t%s\\t%s\\n' \"$n\" \"$p\" \"$icon\" \"$exec\"; fi; done | LC_ALL=C sort -f",
            "sh",
            root.desktopPath
        ]

        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
    }

    property Timer refreshTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    property Timer pollTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!scanProcess.running)
                scanProcess.running = true;
        }
    }

    property Timer trashTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!trashProc.running)
                trashProc.running = true;
        }
    }

    property Process trashProc: Process {
        command: [
            "sh",
            "-c",
            "test -n \"$(ls -A \"$HOME/.local/share/Trash/files\" 2>/dev/null)\" && echo 1 || echo 0"
        ]
        stdout: StdioCollector {
            onStreamFinished: root.trashFull = this.text.trim() === "1"
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.desktopPath]);
        root.refresh();
    }
}
