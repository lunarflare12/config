pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Saved grid cells for desktop widgets and icons.
// State: ~/.config/aurora/desktop-layout.json
// Values: { col, row }  (legacy { x, y } pixels are migrated)

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string statePath: root.home + "/.config/aurora/desktop-layout.json"
    readonly property string legacyPath: root.home + "/.cache/aurora/desktop-widgets.json"

    property var layout: ({})
    property bool hydrating: false

    property FileView stateFile: FileView {
        path: root.statePath
        blockLoading: true
        printErrors: false
        watchChanges: false

        onLoadedChanged: {
            if (loaded)
                root.reload();
        }
    }

    property FileView legacyFile: FileView {
        path: root.legacyPath
        blockLoading: true
        printErrors: false
        watchChanges: false
    }

    Component.onCompleted: root.reload()

    function parseLayout(raw) {
        if (!raw)
            return null;
        try {
            const parsed = JSON.parse(raw);
            if (parsed && typeof parsed === "object" && Object.keys(parsed).length > 0)
                return parsed;
        } catch (e) {
        }
        return null;
    }

    function reload() {
        if (root.hydrating)
            return;

        const fromState = root.parseLayout(root.stateFile.text());
        if (fromState) {
            root.layout = fromState;
            return;
        }

        const fromLegacy = root.parseLayout(root.legacyFile.text());
        if (fromLegacy) {
            root.layout = fromLegacy;
            root.persist();
            return;
        }

        if (Object.keys(root.layout).length > 0)
            return;

        root.layout = ({});
    }

    function persist() {
        root.hydrating = true;
        root.stateFile.setText(JSON.stringify(root.layout));
        Qt.callLater(function () {
            root.hydrating = false;
        });
    }

    function key(monitor, id) {
        return String(monitor || "default") + "/" + String(id || "widget");
    }

    function cellOf(item) {
        if (!item || typeof item !== "object")
            return null;

        if (typeof item.col === "number" && typeof item.row === "number") {
            return {
                col: item.col,
                row: item.row
            };
        }

        if (typeof item.x === "number" && typeof item.y === "number") {
            return {
                col: Math.round((item.x - 16) / 96),
                row: Math.round((item.y - 52) / 96)
            };
        }

        return null;
    }

    function get(monitor, id) {
        if (!id)
            return null;

        const direct = root.cellOf(root.layout[root.key(monitor, id)]);
        if (direct)
            return direct;

        const suffix = "/" + String(id);
        const keys = Object.keys(root.layout);
        for (let i = 0; i < keys.length; i++) {
            if (keys[i].endsWith(suffix)) {
                const cell = root.cellOf(root.layout[keys[i]]);
                if (cell)
                    return cell;
            }
        }

        return null;
    }

    function set(monitor, id, col, row) {
        if (!id || !monitor)
            return;

        const next = ({});
        const keys = Object.keys(root.layout);
        for (let i = 0; i < keys.length; i++)
            next[keys[i]] = root.layout[keys[i]];

        next[root.key(monitor, id)] = {
            col: Math.round(col),
            row: Math.round(row)
        };
        root.layout = next;
        root.persist();
    }
}
