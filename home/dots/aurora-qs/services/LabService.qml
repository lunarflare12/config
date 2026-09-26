pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var vms: []
    property var containers: []
    property var apps: []
    property var wireguard: []
    property var amnezia: []
    property var vless: []
    property bool busy: false
    property string busyName: ""
    property string lastError: ""
    property var hoverTip: null
    property int viewers: 0
    property bool vmsRunningOnly: false
    property bool containersRunningOnly: false
    property bool appsRunningOnly: false
    property bool togglesHydrating: false

    readonly property string togglesPath: (Quickshell.env("HOME") || "") + "/.config/aurora/lab-toggles.json"

    property FileView togglesFile: FileView {
        path: root.togglesPath
        blockLoading: true
        printErrors: false
        watchChanges: false
        onLoadedChanged: {
            if (loaded)
                root.loadToggles();
        }
    }

    function loadToggles() {
        const raw = String(root.togglesFile.text() || "").trim();
        if (!raw)
            return;
        try {
            const data = JSON.parse(raw);
            root.togglesHydrating = true;
            if (data.vms !== undefined)
                root.vmsRunningOnly = !!data.vms;
            if (data.containers !== undefined)
                root.containersRunningOnly = !!data.containers;
            if (data.apps !== undefined)
                root.appsRunningOnly = !!data.apps;
            Qt.callLater(function () {
                root.togglesHydrating = false;
            });
        } catch (e) {}
    }

    function persistToggles() {
        if (root.togglesHydrating)
            return;
        root.togglesFile.setText(JSON.stringify({
            vms: root.vmsRunningOnly,
            containers: root.containersRunningOnly,
            apps: root.appsRunningOnly
        }));
    }

    onVmsRunningOnlyChanged: toggleSave.restart()
    onContainersRunningOnlyChanged: toggleSave.restart()
    onAppsRunningOnlyChanged: toggleSave.restart()

    property Timer toggleSave: Timer {
        interval: 80
        repeat: false
        onTriggered: root.persistToggles()
    }

    function retain() {
        root.viewers += 1;
        if (root.viewers === 1)
            root.refresh();
    }

    function release() {
        if (root.viewers > 0)
            root.viewers -= 1;
    }

    readonly property string ctl: (Quickshell.env("HOME") || "") + "/.config/scripts/lab-ctl.py"
    readonly property int vmCount: root.vms.length
    readonly property int containerCount: root.containers.length
    readonly property int appCount: root.apps.length
    readonly property int tunnelUp: {
        let n = 0;
        const lists = [root.wireguard, root.amnezia, root.vless];
        for (let i = 0; i < lists.length; i++) {
            const list = lists[i];
            for (let j = 0; j < list.length; j++) {
                if (list[j].up)
                    n++;
            }
        }
        return n;
    }

    readonly property var vpnActive: {
        const lists = [root.amnezia, root.wireguard, root.vless];
        for (let i = 0; i < lists.length; i++) {
            const list = lists[i];
            for (let j = 0; j < list.length; j++) {
                if (list[j] && list[j].up)
                    return list[j];
            }
        }
        return null;
    }

    readonly property bool vpnUp: !!root.vpnActive

    readonly property string vpnLabel: {
        const t = root.vpnActive;
        if (!t)
            return "";
        return String(t.label || t.name || "");
    }

    readonly property var vpnSections: {
        const buckets = {};
        const order = [];
        const lists = [
            {
                kind: "wireguard",
                list: root.wireguard
            },
            {
                kind: "amnezia",
                list: root.amnezia
            },
            {
                kind: "vless",
                list: root.vless
            }
        ];
        for (let i = 0; i < lists.length; i++) {
            const kind = lists[i].kind;
            const list = lists[i].list;
            for (let j = 0; j < list.length; j++) {
                const t = list[j];
                const folder = String(t.folder || "").trim() || (kind === "wireguard" ? "WireGuard" : "personal");
                if (!buckets[folder]) {
                    buckets[folder] = [];
                    order.push(folder);
                }
                buckets[folder].push({
                    name: t.name,
                    label: String(t.label || t.name || ""),
                    folder: folder,
                    up: !!t.up,
                    kind: t.kind || kind
                });
            }
        }
        order.sort(function (a, b) {
            return a.localeCompare(b);
        });
        const out = [];
        for (let i = 0; i < order.length; i++) {
            out.push({
                name: order[i],
                tunnels: buckets[order[i]]
            });
        }
        return out;
    }

    readonly property var vpnItems: {
        const sections = root.vpnSections;
        const out = [];
        for (let i = 0; i < sections.length; i++) {
            const section = sections[i];
            out.push({
                item: "folder",
                name: section.name
            });
            const tunnels = section.tunnels || [];
            for (let j = 0; j < tunnels.length; j++) {
                const t = tunnels[j];
                out.push({
                    item: "tunnel",
                    name: t.name,
                    label: t.label,
                    folder: t.folder,
                    up: t.up,
                    kind: t.kind
                });
            }
        }
        return out;
    }

    function tipLines(ct) {
        if (!ct)
            return [];
        const lines = [];
        lines.push("CPU    " + (ct.cpu || "—"));
        lines.push("RAM    " + (ct.mem || "—"));
        lines.push("Net    " + (ct.net || "—"));
        const nets = ct.networks || [];
        if (nets.length) {
            lines.push("Networks");
            for (let i = 0; i < nets.length; i++)
                lines.push("  " + nets[i]);
        } else {
            lines.push("Networks    —");
        }
        const vols = ct.volumes || [];
        if (vols.length) {
            lines.push("Volumes");
            for (let j = 0; j < vols.length; j++)
                lines.push("  " + vols[j]);
        } else {
            lines.push("Volumes    —");
        }
        return lines;
    }

    function showHoverTip(ct, x, y, monitorName) {
        if (!ct)
            return;
        root.hoverTip = {
            name: String(ct.name || ""),
            monitor: String(monitorName || ""),
            x: x,
            y: y,
            lines: root.tipLines(ct)
        };
    }

    function hideHoverTip(name) {
        if (!root.hoverTip)
            return;
        if (name && root.hoverTip.name !== name)
            return;
        root.hoverTip = null;
    }

    function sameJson(a, b) {
        try {
            return JSON.stringify(a) === JSON.stringify(b);
        } catch (e) {
            return false;
        }
    }

    function ingest(payload) {
        if (!payload || typeof payload !== "object")
            return;
        const vms = Array.isArray(payload.vms) ? payload.vms : [];
        const containers = Array.isArray(payload.containers) ? payload.containers : [];
        const apps = Array.isArray(payload.apps) ? payload.apps : [];
        const wireguard = Array.isArray(payload.wireguard) ? payload.wireguard : [];
        const amnezia = Array.isArray(payload.amnezia) ? payload.amnezia : [];
        const vless = Array.isArray(payload.vless) ? payload.vless : [];
        if (!root.sameJson(root.vms, vms))
            root.vms = vms;
        if (!root.sameJson(root.containers, containers))
            root.containers = containers;
        if (!root.sameJson(root.apps, apps))
            root.apps = apps;
        if (!root.sameJson(root.wireguard, wireguard))
            root.wireguard = wireguard;
        if (!root.sameJson(root.amnezia, amnezia))
            root.amnezia = amnezia;
        if (!root.sameJson(root.vless, vless))
            root.vless = vless;
        root.refreshHover();
    }

    function refreshHover() {
        const tip = root.hoverTip;
        if (!tip || !tip.name)
            return;
        const lists = [root.containers, root.apps];
        for (let i = 0; i < lists.length; i++) {
            const list = lists[i];
            for (let j = 0; j < list.length; j++) {
                if (list[j].name !== tip.name)
                    continue;
                root.hoverTip = {
                    name: tip.name,
                    monitor: tip.monitor,
                    x: tip.x,
                    y: tip.y,
                    lines: root.tipLines(list[j])
                };
                return;
            }
        }
    }

    function parseStdout(text) {
        const raw = String(text || "").trim();
        if (!raw)
            return;
        try {
            root.ingest(JSON.parse(raw.split("\n")[0]));
        } catch (e) {}
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function prettyContainer(name) {
        const map = {
            "chrome-dd": "Chrome DD",
            "chrome-az": "Chrome Aziza",
            "chrome-hika": "Chrome hika911",
            "chrome-sciencesoft": "Chrome ScienceSoft",
            "telegram-1": "Telegram 1",
            "telegram-2": "Telegram 2",
            "vscode": "VS Code",
            "obsidian": "Obsidian",
            "openlens": "OpenLens",
            "prismlauncher": "Prism Launcher",
            "qbittorrent": "qBittorrent",
            "libreoffice": "LibreOffice",
            "firefox": "Firefox",
            "zen": "Zen",
            "spotify": "Spotify",
            "idea": "IntelliJ IDEA",
            "steam": "Steam",
            "overwatch": "Overwatch",
            "terraria": "Terraria",
            "albion": "Albion Online",
            "ollama": "Ollama",
            "omniroute": "Omniroute"
        };
        return map[name] || String(name || "").replace(/-/g, " ");
    }

    function prettyAction(action) {
        const map = {
            stop: "Stopped",
            start: "Started",
            restart: "Restarted",
            pause: "Paused",
            unpause: "Resumed",
            rm: "Removed",
            vpn: "Toggled"
        };
        return map[action] || String(action || "");
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "Aurora", "-u", "low", "-i", "dialog-information", summary, body || ""]);
    }

    function notifyLab(tag, ok) {
        const raw = String(tag || "");
        const cut = raw.indexOf(":");
        const action = cut >= 0 ? raw.slice(0, cut) : raw;
        const name = cut >= 0 ? raw.slice(cut + 1) : "";
        if (ok)
            root.notify(root.prettyAction(action) || "Done", root.prettyContainer(name));
        else
            root.notify("Failed", root.lastError || root.prettyContainer(name) || "Command failed");
    }

    function toggleVpn(kind, name) {
        if (!kind || !name)
            return;
        if (kind !== "wireguard" && kind !== "amnezia" && kind !== "vless")
            return;
        if (!root.validCt(name))
            return;
        root.run(["vpn-ctl", "gui-toggle", kind, name], "vpn:" + name);
    }

    function openVm(name) {
        if (!name)
            return;
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", "virt-viewer", "--connect", "qemu:///system", "--attach", name]);
    }

    function vmDo(action, name) {
        if (!root.validCt(name) || root.busy)
            return;
        root.run(["python3", root.ctl, "vm", action, name], action + ":" + name);
    }

    function activateVm(vm) {
        if (!vm || !vm.name)
            return;
        if (vm.state === "running" || vm.state === "paused") {
            root.openVm(vm.name);
            return;
        }
        root.vmDo("start", vm.name);
    }

    function validCt(name) {
        return /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/.test(String(name || ""));
    }

    function dockerDo(action, name) {
        if (!root.validCt(name) || root.busy)
            return;
        root.run(["python3", root.ctl, "docker", action, name], action + ":" + name);
    }

    function togglePause(ct) {
        if (!ct || !ct.name)
            return;
        const gui = /^(chrome-|vscode|obsidian|openlens|prismlauncher|qbittorrent|libreoffice|firefox|zen|spotify|idea|telegram-|steam|overwatch|terraria|albion)/.test(String(ct.name || ""));
        if (gui) {
            root.toggleRun(ct);
            return;
        }
        root.dockerDo(ct.state === "paused" ? "unpause" : "pause", ct.name);
    }

    function toggleRun(ct) {
        if (!ct || !ct.name)
            return;
        root.dockerDo(ct.state === "running" ? "stop" : "start", ct.name);
    }

    function restartContainer(name) {
        root.dockerDo("restart", name);
    }

    function removeContainer(name) {
        root.dockerDo("rm", name);
    }

    function copyImage(image) {
        const text = String(image || "");
        if (!text)
            return;
        Quickshell.execDetached(["wl-copy", "--", text]);
        root.notify("Image", text);
    }

    function enterContainer(name) {
        if (!root.validCt(name))
            return;
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", "kitty", "--class", "termfloat", "-e", "sh", "-c", "docker exec -it " + name + " bash 2>/dev/null || docker exec -it " + name + " sh"]);
    }

    property var actionQueue: []
    property string currentTag: ""

    property Process actionProc: Process {
        id: actionProcImpl

        property string errText: ""
        property string outText: ""

        stdout: StdioCollector {
            onStreamFinished: actionProcImpl.outText = text.trim()
        }

        stderr: StdioCollector {
            onStreamFinished: actionProcImpl.errText = text.trim()
        }

        onExited: function (exitCode) {
            const err = actionProcImpl.errText;
            const tag = root.currentTag;
            actionProcImpl.errText = "";
            actionProcImpl.outText = "";
            root.currentTag = "";
            root.busyName = "";
            root.busy = false;
            root.lastError = exitCode !== 0 ? (err !== "" ? err : "Command failed") : "";
            if (exitCode === 0)
                root.notifyLab(tag, true);
            else if (root.lastError)
                root.notifyLab(tag, false);
            root.refresh();
            settleTimer.restart();
            root.drainQueue();
        }
    }

    function drainQueue() {
        if (root.busy || root.actionQueue.length === 0)
            return;
        const next = root.actionQueue.shift();
        root.busy = true;
        root.currentTag = next.tag;
        const cut = String(next.tag || "").indexOf(":");
        root.busyName = cut >= 0 ? String(next.tag).slice(cut + 1) : "";
        actionProcImpl.command = next.command;
        actionProcImpl.running = true;
    }

    function run(command, tag) {
        const q = root.actionQueue.slice();
        q.push({
            command: command,
            tag: tag === undefined ? "" : tag
        });
        root.actionQueue = q;
        root.drainQueue();
    }

    property Process statusProc: Process {
        command: ["python3", root.ctl, "status-light"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStdout(text)
        }
    }

    property Timer poll: Timer {
        interval: 3000
        repeat: true
        running: root.viewers > 0 && !root.busy
        onTriggered: root.refresh()
    }

    property Timer vpnWatch: Timer {
        interval: 3000
        repeat: false
        onTriggered: root.refresh()
    }

    function refreshVpn() {
        if (!vpnStatusProc.running)
            vpnStatusProc.running = true;
    }

    property Process vpnStatusProc: Process {
        command: ["python3", root.ctl, "status-vpn"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = String(text || "").trim();
                if (!raw)
                    return;
                try {
                    const payload = JSON.parse(raw.split("\n")[0]);
                    if (!payload || typeof payload !== "object")
                        return;
                    const wireguard = Array.isArray(payload.wireguard) ? payload.wireguard : root.wireguard;
                    const amnezia = Array.isArray(payload.amnezia) ? payload.amnezia : root.amnezia;
                    const vless = Array.isArray(payload.vless) ? payload.vless : root.vless;
                    if (!root.sameJson(root.wireguard, wireguard))
                        root.wireguard = wireguard;
                    if (!root.sameJson(root.amnezia, amnezia))
                        root.amnezia = amnezia;
                    if (!root.sameJson(root.vless, vless))
                        root.vless = vless;
                } catch (e) {}
            }
        }
    }

    property Timer vpnPoll: Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: root.refreshVpn()
    }

    property Timer settleTimer: Timer {
        interval: 900
        repeat: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        root.loadToggles();
        root.refreshVpn();
        if (root.viewers > 0)
            root.refresh();
    }
}
