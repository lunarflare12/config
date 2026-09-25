pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Aurora Wallpaper Service

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallpaperDirectory: root.home + "/Pictures/Wallpapers"
    readonly property string thumbDirectory: root.home + "/.cache/aurora/wallpaper-thumbs"
    readonly property string statePath: root.home + "/.cache/aurora/current-wallpaper"
    readonly property string persistPath: root.home + "/.local/state/aurora/wallpaper"
    readonly property string currentNamePath: root.wallpaperDirectory + "/.current"
    readonly property string thumbScript: root.home + "/.config/scripts/cache-wallpaper-thumbs.sh"

    property bool scanning: false
    property string error: ""
    property var wallpapers: []

    property FileView stateFile: FileView {
        path: root.statePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }

    property FileView persistFile: FileView {
        path: root.persistPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }

    property FileView nameFile: FileView {
        path: root.currentNamePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }

    function normalize(raw) {
        if (!raw)
            return "";
        let path = String(raw).trim();
        if (!path.length)
            return "";
        // Migrated: ~/Wallpapers → ~/Pictures/Wallpapers
        if (path.indexOf(root.home + "/Wallpapers/") === 0)
            path = root.wallpaperDirectory + path.slice((root.home + "/Wallpapers").length);
        else if (path === root.home + "/Wallpapers")
            path = root.wallpaperDirectory;
        if (path.indexOf("/") < 0)
            path = root.wallpaperDirectory + "/" + path;
        return path;
    }

    readonly property string current: {
        const cache = root.normalize(root.stateFile.text());
        if (cache.length)
            return cache;
        const persist = root.normalize(root.persistFile.text());
        if (persist.length)
            return persist;
        return root.normalize(root.nameFile.text());
    }

    property Process scanProcess: Process {
        command: ["sh", "-c", "thumbdir=\"$2\"; mkdir -p \"$thumbdir\"; find -L \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' \\) ! -name '.*' -printf '%f\\t%p\\n' 2>/dev/null | sort -f | while IFS=$(printf '\\t') read -r name path; do stem=${name%.*}; thumb=\"$thumbdir/$stem.jpg\"; [ -f \"$thumb\" ] || thumb=$path; printf '%s\\t%s\\t%s\\n' \"$name\" \"$path\" \"$thumb\"; done", "sh", root.wallpaperDirectory, root.thumbDirectory]

        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }

        onExited: function (exitCode, exitStatus) {
            root.scanning = false;

            if (exitCode !== 0 && root.wallpapers.length === 0)
                root.error = "Could not read " + root.wallpaperDirectory;
        }
    }

    property Process thumbProcess: Process {
        command: [root.thumbScript, root.wallpaperDirectory]
        onExited: {
            if (!root.scanProcess.running)
                root.scanProcess.running = true;
        }
    }

    function refresh() {
        root.error = "";
        if (!root.scanProcess.running) {
            root.scanning = root.wallpapers.length === 0;
            root.scanProcess.running = true;
        }
        if (!root.thumbProcess.running)
            root.thumbProcess.running = true;
    }

    function isLivePath(path) {
        const n = String(path || "").toLowerCase();
        return n.endsWith(".gif") || n.endsWith(".mp4") || n.endsWith(".webm") || n.endsWith(".mkv") || n.endsWith(".mov");
    }

    function previewOf(path) {
        const raw = root.normalize(path);
        if (!raw)
            return "";
        const walls = root.wallpapers || [];
        for (let i = 0; i < walls.length; i++) {
            if (walls[i].path === raw && walls[i].thumb && !root.isLivePath(walls[i].thumb))
                return walls[i].thumb;
        }
        if (!root.isLivePath(raw))
            return raw;
        const name = raw.split("/").pop();
        const stem = name.replace(/\.[^.]+$/, "");
        return root.thumbDirectory + "/" + stem + ".jpg";
    }

    readonly property string currentPreview: root.previewOf(root.current)

    function sameList(next) {
        const cur = root.wallpapers;
        if (cur.length !== next.length)
            return false;

        for (let i = 0; i < cur.length; i++) {
            if (cur[i].path !== next[i].path || cur[i].thumb !== next[i].thumb || !!cur[i].live !== !!next[i].live)
                return false;
        }

        return true;
    }

    function ingest(text) {
        if (!text) {
            if (root.wallpapers.length === 0)
                root.wallpapers = [];
            return;
        }

        const lines = text.split("\n");
        const out = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (!line || line.trim().length === 0)
                continue;
            const parts = line.split("\t");
            if (parts.length < 2)
                continue;
            const name = parts[0];
            const path = parts[1];
            const thumb = parts.length > 2 && parts[2].length > 0 ? parts[2] : path;

            out.push({
                "name": name,
                "path": path,
                "thumb": thumb,
                "live": root.isLivePath(path),
                "label": name.replace(/\.[^.]+$/, "")
            });
        }

        if (root.sameList(out))
            return;
        root.wallpapers = out;
    }

    Component.onCompleted: root.refresh()

    readonly property int count: root.wallpapers.length

    function filtered(want) {
        const all = root.wallpapers;
        if (want !== "live" && want !== "static")
            return all;
        const live = want === "live";
        const out = [];
        for (let i = 0; i < all.length; i++) {
            if (!!all[i].live === live)
                out.push(all[i]);
        }
        return out;
    }

    function search(query) {
        const all = root.wallpapers;

        if (!query || query.trim().length === 0)
            return all;

        const q = query.trim().toLowerCase();
        const out = [];

        for (let i = 0; i < all.length; i++) {
            if (all[i].label.toLowerCase().indexOf(q) !== -1)
                out.push(all[i]);
        }

        return out;
    }

    function apply(path) {
        if (!path || path.length === 0)
            return;
        Quickshell.execDetached([root.home + "/.config/scripts/set-wallpaper.sh", path]);
    }
}
