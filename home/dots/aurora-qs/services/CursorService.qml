pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Aurora cursor packs. Same apply path as wallpapers/themes.

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cataloguePath: Quickshell.shellDir + "/assets/cursors/catalogue.json"
    readonly property string previewDir: Quickshell.shellDir + "/assets/cursors/previews"
    readonly property string statePath: root.home + "/.cache/aurora/current-cursor"
    readonly property string sizePath: root.home + "/.cache/aurora/current-cursor-size"
    readonly property string applyScript: root.home + "/.config/scripts/set-cursor.sh"
    readonly property string bashBin: "/run/current-system/sw/bin/bash"
    readonly property int minSize: 24
    readonly property int maxSize: 96
    readonly property var sizeSteps: [24, 32, 48, 64, 96]

    property var cursors: []
    property int pendingSize: 0
    property string kindFilter: "all"

    property FileView catalogueFile: FileView {
        path: root.cataloguePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
        onLoadedChanged: if (this.loaded)
            root.ingest()
        onTextChanged: root.ingest()
    }

    property FileView stateFile: FileView {
        path: root.statePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }

    property FileView sizeFile: FileView {
        path: root.sizePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
    }

    readonly property string defaultId: "macos"
    readonly property int defaultSize: 24

    readonly property string activeId: {
        const raw = root.stateFile.text();
        if (!raw)
            return root.defaultId;
        const trimmed = raw.trim();
        return trimmed.length > 0 ? trimmed : root.defaultId;
    }

    readonly property int activeSize: {
        const raw = root.sizeFile.text();
        const parsed = raw ? parseInt(String(raw).trim(), 10) : root.defaultSize;
        if (isNaN(parsed))
            return root.defaultSize;
        return Math.max(root.minSize, Math.min(root.maxSize, parsed));
    }

    readonly property int count: root.cursors.length

    function ingest() {
        const raw = root.catalogueFile.text();
        let list = [];
        if (raw) {
            try {
                const parsed = JSON.parse(raw);
                if (parsed && parsed.length)
                    list = parsed;
                else if (parsed && parsed.cursors)
                    list = parsed.cursors;
            } catch (e) {
                list = [];
            }
        }

        const out = [];
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            if (!item || !item.id)
                continue;
            const thumbName = item.thumb || (item.id + ".png");
            out.push({
                "id": item.id,
                "name": item.name || item.id,
                "theme": item.theme || item.id,
                "animated": !!item.animated,
                "thumb": root.previewDir + "/" + thumbName
            });
        }
        root.cursors = out;
    }

    function filtered(kind) {
        const want = kind && kind.length > 0 ? kind : root.kindFilter;
        const list = root.cursors;
        if (want !== "static" && want !== "animated")
            return list;
        const animated = want === "animated";
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (!!list[i].animated === animated)
                out.push(list[i]);
        }
        return out;
    }

    function itemById(id) {
        const list = root.cursors;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i];
        }
        return null;
    }

    function clampSize(size) {
        const n = Math.round(Number(size));
        if (isNaN(n))
            return root.defaultSize;
        const steps = root.sizeSteps;
        let best = steps[0];
        let dist = Math.abs(n - best);
        for (let i = 1; i < steps.length; i++) {
            const d = Math.abs(n - steps[i]);
            if (d < dist) {
                best = steps[i];
                dist = d;
            }
        }
        return best;
    }

    function hypr(args) {
        Quickshell.execDetached(["hyprctl"].concat(args));
    }

    function apply(id, size) {
        const item = root.itemById(id);
        const key = id && id.length > 0 ? id : root.activeId;
        if (!key)
            return;
        const theme = ((item && item.theme) ? item.theme : key).replace(/'/g, "");
        const px = root.clampSize(size === undefined ? root.activeSize : size);
        root.hypr(["eval", "hl.env('HYPRCURSOR_THEME', '" + theme + "')"]);
        root.hypr(["eval", "hl.env('HYPRCURSOR_SIZE', '" + px + "')"]);
        root.hypr(["eval", "hl.env('XCURSOR_THEME', '" + theme + "')"]);
        root.hypr(["eval", "hl.env('XCURSOR_SIZE', '" + px + "')"]);
        root.hypr(["eval", "hl.config({ cursor = { enable_hyprcursor = true, no_hardware_cursors = true, use_cpu_buffer = false, hide_on_key_press = false, default_monitor = 'DP-1' } })"]);
        root.hypr(["setcursor", theme, String(px)]);
        Quickshell.execDetached([root.applyScript, key, String(px), theme]);
    }

    function applySize(size) {
        const px = root.clampSize(Math.round(Number(size) / 2) * 2);
        if (px === root.activeSize && px === root.pendingSize)
            return;
        root.pendingSize = px;
        root.apply(root.activeId, px);
    }

    Component.onCompleted: root.ingest()
}
