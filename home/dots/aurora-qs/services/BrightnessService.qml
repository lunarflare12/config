pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../core" as Core

Singleton {
    id: root

    readonly property string ctl: (Quickshell.env("HOME") || "") + "/.config/scripts/monitor-brightness"
    readonly property string statePath: (Quickshell.env("HOME") || "") + "/.local/state/aurora/brightness.json"

    property var displayList: []
    property var levels: ({})
    property var buses: ({})
    property string selectedName: ""
    property bool primed: false
    property bool interacting: false
    property bool dragging: false

    // Displays waiting for a debounced ddcutil write.
    property var pendingTargets: []

    readonly property int stepSize: 5
    readonly property bool popupOpen: Core.PopupManager.isOpen("brightness")
    readonly property bool available: root.displayList.length > 0

    readonly property var ddcDisplays: {
        const list = root.displayList;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].backend === "ddc")
                out.push(list[i]);
        }
        return out;
    }

    readonly property var selected: root.displayOf(root.selectedName) || (root.ddcDisplays.length > 0 ? root.ddcDisplays[0] : null)
    readonly property string selectedLabel: root.selected ? (root.selected.label || root.selected.name) : "No display"
    readonly property int level: {
        const lv = root.levels;
        const name = root.selected ? root.selected.name : "";
        const value = lv[name];
        return typeof value === "number" && !isNaN(value) ? value : 100;
    }
    readonly property real fraction: root.level / 100

    function dimOf(name) {
        const percent = root.percentOf(name);
        return Math.max(0, Math.min(0.72, 1 - percent / 100));
    }

    function displayOf(name) {
        const list = root.displayList;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === name)
                return list[i];
        }
        return null;
    }

    function percentOf(name) {
        const value = root.levels[name];
        if (typeof value === "number" && !isNaN(value))
            return value;
        return 100;
    }

    function isDdc(name) {
        const row = root.displayOf(name);
        return !!(row && row.backend === "ddc");
    }

    function backendLabel(row) {
        if (!row)
            return "";
        return row.backend === "ddc" ? "Hardware DDC" : "Software";
    }

    function targetName(name) {
        if (root.displayOf(name))
            return name;
        if (root.selected)
            return root.selected.name;
        return root.displayList.length ? root.displayList[0].name : "";
    }

    function patchLevel(name, percent) {
        const next = Object.assign({}, root.levels);
        next[name] = percent;
        root.levels = next;
        root.selectedName = name;
    }

    function setDisplayPercent(name, percent, commit) {
        const target = root.targetName(name);
        if (!target)
            return;

        const clamped = Math.max(0, Math.min(100, Math.round(percent)));
        root.patchLevel(target, clamped);
        root.markInteraction();
        Core.OsdController.show("brightness", clamped / 100, false);

        root.pendingTargets = [
            {
                name: target,
                percent: clamped
            }
        ];
        if (commit)
            root.flushDdc();
        else
            applyDebounce.restart();
    }

    function setAllPercent(percent, commit) {
        const list = root.displayList;
        if (!list.length)
            return;

        const next = Object.assign({}, root.levels);
        const targets = [];
        const clamped = Math.max(0, Math.min(100, Math.round(percent)));

        for (let i = 0; i < list.length; i++) {
            next[list[i].name] = clamped;
            targets.push({
                name: list[i].name,
                percent: clamped
            });
        }

        root.levels = next;
        root.markInteraction();
        Core.OsdController.show("brightness", clamped / 100, false);

        root.pendingTargets = targets;
        if (commit)
            root.flushDdc();
        else
            applyDebounce.restart();
    }

    function setPercent(percent) {
        root.setDisplayPercent(root.selectedName, percent, true);
    }

    function step(up) {
        const name = root.targetName(root.selectedName);
        if (!name)
            return;
        root.setDisplayPercent(name, root.percentOf(name) + (up ? root.stepSize : -root.stepSize), false);
    }

    function stepDisplay(name, up) {
        root.setDisplayPercent(name, root.percentOf(name) + (up ? root.stepSize : -root.stepSize), false);
    }

    function select(name) {
        if (!name)
            return;
        root.selectedName = name;
        persistDebounce.restart();
    }

    function cycle() {
        const list = root.ddcDisplays.length ? root.ddcDisplays : root.displayList;
        if (list.length < 2)
            return;
        let idx = 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === root.selectedName) {
                idx = i;
                break;
            }
        }
        root.select(list[(idx + 1) % list.length].name);
        Core.OsdController.show("brightness", root.percentOf(root.selectedName) / 100, false);
    }

    function flushDdc() {
        applyDebounce.stop();
        const targets = root.pendingTargets;
        for (let i = 0; i < targets.length; i++) {
            const t = targets[i];
            if (!t || !t.name)
                continue;
            Quickshell.execDetached([root.ctl, "-d", t.name, "set", String(t.percent) + "%"]);
        }
        persistDebounce.restart();
    }

    function markInteraction() {
        root.interacting = true;
        root.interactionCooldown.restart();
    }

    function ingest(payload) {
        if (!payload || !payload.displays)
            return;

        const list = payload.displays;
        const meta = [];
        const nextBuses = {};
        const nextLevels = Object.assign({}, root.levels);

        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            const name = String(d.name || "");
            if (!name)
                continue;
            const backend = d.backend === "ddc" ? "ddc" : "gamma";
            meta.push({
                name: name,
                label: String(d.label || name),
                backend: backend,
                bus: d.bus ? Number(d.bus) : 0
            });
            if (d.bus)
                nextBuses[name] = Number(d.bus);
            if (!root.primed || nextLevels[name] === undefined)
                nextLevels[name] = Math.max(0, Math.min(100, Number(d.percent) || 100));
        }

        root.displayList = meta;
        root.buses = nextBuses;
        root.levels = nextLevels;

        const ddcNames = [];
        for (let i = 0; i < meta.length; i++) {
            if (meta[i].backend === "ddc")
                ddcNames.push(meta[i].name);
        }
        if (ddcNames.length) {
            if (ddcNames.indexOf(root.selectedName) === -1)
                root.selectedName = ddcNames.indexOf(payload.selected) !== -1 ? payload.selected : ddcNames[0];
        } else if (!root.selectedName && meta.length) {
            root.selectedName = payload.selected || meta[0].name;
        }
        root.primed = true;
    }

    function parseStdout(text) {
        const raw = String(text || "").trim();
        if (!raw)
            return;
        try {
            root.ingest(JSON.parse(raw.split("\n")[0]));
        } catch (e) {}
    }

    function persist() {
        const displays = {};
        const ddc = {};
        const list = root.displayList;
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            displays[d.name] = {
                percent: root.percentOf(d.name),
                backend: d.backend === "ddc" ? "ddc" : "gamma"
            };
            if (root.buses[d.name])
                ddc[d.name] = {
                    bus: root.buses[d.name]
                };
        }
        stateFile.setText(JSON.stringify({
            selected: root.selectedName,
            gamma: 140,
            displays: displays,
            ddc: ddc
        }));
    }

    property FileView stateFile: FileView {
        path: root.statePath
        blockLoading: true
        printErrors: false
        watchChanges: false
    }

    property Process discoverProc: Process {
        command: [root.ctl, "--json", "--discover"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStdout(text)
        }
    }

    property Timer applyDebounce: Timer {
        interval: 80
        repeat: false
        onTriggered: root.flushDdc()
    }

    property Timer persistDebounce: Timer {
        interval: 250
        repeat: false
        onTriggered: root.persist()
    }

    property Timer interactionCooldown: Timer {
        interval: 800
        repeat: false
        onTriggered: {
            root.interacting = false;
            root.dragging = false;
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", "140"]);
        discoverProc.running = true;
    }
}
