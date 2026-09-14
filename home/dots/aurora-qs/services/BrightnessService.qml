pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../core" as Core

Singleton {
    id: root

    readonly property string bin: (Quickshell.env("HOME") || "") + "/.config/scripts/monitor-brightness"
    readonly property string statePath: (Quickshell.env("HOME") || "") + "/.local/state/aurora/brightness.json"

    property var displayList: []
    property var levels: ({})
    property var buses: ({})
    property string selectedName: ""
    property bool primed: false
    property bool interacting: false
    property bool dragging: false

    readonly property int stepSize: 5
    readonly property bool popupOpen: Core.PopupManager.isOpen("brightness")
    readonly property bool available: root.displayList.length > 0

    readonly property var selected: root.displayOf(root.selectedName) || (root.displayList.length > 0 ? root.displayList[0] : null)
    readonly property string selectedLabel: root.selected ? (root.selected.label || root.selected.name) : "No display"
    readonly property int level: {
        const lv = root.levels;
        const name = root.selectedName;
        const value = lv[name];
        return typeof value === "number" && !isNaN(value) ? value : 100;
    }
    readonly property real fraction: root.level / 100

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

    function dimOf(name) {
        const row = root.displayOf(name);
        if (!row || row.backend === "ddc")
            return 0;
        return Math.max(0, Math.min(0.8, (100 - root.percentOf(name)) / 100 * 0.8));
    }

    function backendLabel(row) {
        if (!row)
            return "";
        return row.backend === "ddc" ? "Hardware" : "Software";
    }

    function patchLevel(name, percent) {
        const next = Object.assign({}, root.levels);
        next[name] = percent;
        root.levels = next;
        if (name === root.selectedName || root.selectedName === "")
            root.selectedName = name;
    }

    function setDisplayPercent(name, percent, commit) {
        const row = root.displayOf(name) || root.selected;
        const target = row ? row.name : name;
        if (!target)
            return;
        const backend = row ? row.backend : "soft";
        const lo = backend === "ddc" ? 0 : 10;
        const clamped = Math.max(lo, Math.min(100, Math.round(percent)));

        root.patchLevel(target, clamped);
        root.markInteraction();

        if (!root.popupOpen)
            Core.OsdController.show("brightness", clamped / 100, false);

        if (backend !== "ddc") {
            persistDebounce.restart();
            return;
        }

        applyDebounce.targetName = target;
        applyDebounce.targetPercent = clamped;
        if (commit)
            root.flushDdc();
        else
            applyDebounce.restart();
    }

    function setPercent(percent) {
        root.setDisplayPercent(root.selectedName, percent, true);
    }

    function step(up) {
        root.stepDisplay(root.selectedName, up);
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
        const list = root.displayList;
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
    }

    function flushDdc() {
        applyDebounce.stop();
        const name = applyDebounce.targetName;
        const percent = applyDebounce.targetPercent;
        const bus = root.buses[name];
        if (!name || !bus)
            return;
        Quickshell.execDetached([
            "ddcutil",
            "--bus",
            String(bus),
            "--noverify",
            "--sleep-multiplier",
            ".15",
            "setvcp",
            "10",
            String(percent)
        ]);
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
            const backend = d.backend === "ddc" ? "ddc" : "soft";
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
        if (!root.selectedName && meta.length)
            root.selectedName = payload.selected || meta[0].name;
        root.primed = true;
    }

    function parseStdout(text) {
        const raw = String(text || "").trim();
        if (!raw)
            return;
        try {
            root.ingest(JSON.parse(raw.split("\n")[0]));
        } catch (e) {
        }
    }

    function persist() {
        const displays = {};
        const ddc = {};
        const list = root.displayList;
        for (let i = 0; i < list.length; i++) {
            const d = list[i];
            displays[d.name] = {
                percent: root.percentOf(d.name),
                backend: d.backend === "ddc" ? "ddc" : "hypr"
            };
            if (root.buses[d.name])
                ddc[d.name] = {
                    bus: root.buses[d.name]
                };
        }
        stateFile.setText(JSON.stringify({
            selected: root.selectedName,
            gamma: 100,
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
        command: ["python3", root.bin, "--json", "--discover"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStdout(text)
        }
    }

    property Timer applyDebounce: Timer {
        property string targetName: ""
        property int targetPercent: 0
        interval: 220
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
        Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", "100"]);
        discoverProc.running = true;
    }
}
