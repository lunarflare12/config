pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../core" as Core

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string ctl: root.home + "/.config/scripts/shader-ctl.sh"
    readonly property string statusPath: root.home + "/.cache/aurora/shader-status.json"

    property var games: []
    property bool building: false
    property bool checking: false
    property bool stale: false
    property bool updating: false
    property string buildingName: ""
    property string updatingName: ""
    property string error: ""
    property string hostMonitor: ""
    property string barKind: ""
    property string barName: ""
    property real barPercent: 0
    property real downloadPercent: 0
    property int checkedAt: 0

    property FileView statusFile: FileView {
        path: root.statusPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: root.ingest(this.text())
    }

    property Process statusProc: Process {
        command: [root.ctl, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
    }

    property Process buildProc: Process {
        command: [root.ctl, "build"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
        onRunningChanged: {
            if (running)
                root.building = true;
        }
        onExited: function () {
            root.refresh();
        }
    }

    property Process oneProc: Process {
        property string appid: ""
        command: [root.ctl, "build", oneProc.appid]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
        onExited: function () {
            root.refresh();
        }
    }

    property Timer pollTimer: Timer {
        interval: (root.building || root.updating) ? 1500 : 30000
        repeat: true
        running: root.building || root.updating || Core.PopupManager.current === "shader"
        onTriggered: root.refresh()
    }

    property Timer bootBuild: Timer {
        interval: 25000
        repeat: false
        running: false
        onTriggered: root.refresh()
    }

    function ingest(text) {
        if (!text || !String(text).trim())
            return;
        try {
            const data = JSON.parse(String(text).trim());
            root.games = data.games || [];
            root.building = !!data.building;
            root.stale = !!data.stale;
            root.updating = !!data.updating;
            root.buildingName = data.buildingName || "";
            root.updatingName = data.updatingName || "";
            root.barKind = data.barKind || "";
            root.barName = data.barName || "";
            root.barPercent = Number(data.barPercent) || 0;
            root.downloadPercent = Number(data.downloadPercent) || 0;
            root.error = data.error || "";
            root.checkedAt = Number(data.checkedAt) || 0;
        } catch (e) {}
    }

    function refresh() {
        if (!root.statusProc.running)
            root.statusProc.running = true;
    }

    function resolveMonitor(name) {
        const mon = name || Core.Session.focusedMonitorName();
        if (mon)
            return mon;
        const screens = Quickshell.screens;
        if (screens && screens.length)
            return Core.Session.monitorNameForScreen(screens[0]);
        return "DP-1";
    }

    function showOn(name) {
        root.hostMonitor = root.resolveMonitor(name);
        Core.PopupManager.open("shaders", 0, 0);
    }

    function toggleOn(name) {
        const mon = root.resolveMonitor(name);
        if (Core.PopupManager.isOpen("shaders") && root.hostMonitor === mon) {
            Core.PopupManager.close();
            return;
        }
        root.hostMonitor = mon;
        Core.PopupManager.open("shaders", 0, 0);
    }

    function check() {
        if (root.checkProc.running)
            return;
        root.checking = true;
        root.checkProc.running = true;
    }

    function checkOne(appid) {
        if (root.checkOneProc.running || root.checkProc.running)
            return;
        root.checkOneProc.appid = appid;
        root.checking = true;
        root.checkOneProc.running = true;
    }

    function updateOne(appid) {
        if (root.buildProc.running || root.oneProc.running || root.updateProc.running)
            return;
        root.updateProc.appid = appid;
        root.building = true;
        root.updateProc.running = true;
    }

    function build() {
        if (root.buildProc.running || root.oneProc.running)
            return;
        root.building = true;
        root.buildProc.running = true;
    }

    function buildOne(appid) {
        if (root.oneProc.running || root.buildProc.running || root.updateProc.running)
            return;
        root.oneProc.appid = appid;
        root.building = true;
        root.oneProc.running = true;
    }

    function stop() {
        if (root.stopProc.running)
            return;
        root.stopProc.running = true;
    }

    property Process checkProc: Process {
        command: [root.ctl, "check"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
        onExited: function () {
            root.checking = false;
            root.refresh();
        }
    }

    property Process checkOneProc: Process {
        property string appid: ""
        command: [root.ctl, "check", checkOneProc.appid]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
        onExited: function () {
            root.checking = false;
            root.refresh();
        }
    }

    property Process updateProc: Process {
        property string appid: ""
        command: [root.ctl, "update", updateProc.appid]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
        onExited: function () {
            root.refresh();
        }
    }

    property Process stopProc: Process {
        command: [root.ctl, "stop"]
        stdout: StdioCollector {
            onStreamFinished: root.ingest(this.text)
        }
        onExited: function () {
            root.building = false;
            root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
