pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var vms: []
    property var containers: []
    property var wireguard: []
    property var amnezia: []
    property bool busy: false
    property string lastError: ""

    readonly property string ctl: (Quickshell.env("HOME") || "") + "/.config/scripts/lab-ctl.py"
    readonly property int vmCount: root.vms.length
    readonly property int containerCount: root.containers.length
    readonly property int tunnelUp: {
        let n = 0;
        const wg = root.wireguard;
        const awg = root.amnezia;
        for (let i = 0; i < wg.length; i++) {
            if (wg[i].up)
                n++;
        }
        for (let i = 0; i < awg.length; i++) {
            if (awg[i].up)
                n++;
        }
        return n;
    }

    readonly property var vpnSections: {
        const buckets = {};
        const order = [];
        const lists = [
            { kind: "wireguard", list: root.wireguard },
            { kind: "amnezia", list: root.amnezia }
        ];
        for (let i = 0; i < lists.length; i++) {
            const kind = lists[i].kind;
            const list = lists[i].list;
            for (let j = 0; j < list.length; j++) {
                const t = list[j];
                const folder = String(t.folder || "").trim() || (kind === "amnezia" ? "Amnezia" : "WireGuard");
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
            out.push({ name: order[i], tunnels: buckets[order[i]] });
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

    function ingest(payload) {
        if (!payload || typeof payload !== "object")
            return;
        root.vms = Array.isArray(payload.vms) ? payload.vms : [];
        root.containers = Array.isArray(payload.containers) ? payload.containers : [];
        root.wireguard = Array.isArray(payload.wireguard) ? payload.wireguard : [];
        root.amnezia = Array.isArray(payload.amnezia) ? payload.amnezia : [];
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

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function notify(summary, body) {
        Quickshell.execDetached(["notify-send", "-a", "Aurora", "-u", "low", summary, body || ""]);
    }

    function toggleVpn(kind, name) {
        if (!kind || !name)
            return;
        if (kind !== "wireguard" && kind !== "amnezia")
            return;
        if (!root.validCt(name))
            return;
        root.run(["python3", root.ctl, "gui-toggle", kind, name], "vpn:" + name);
        root.vpnWatch.restart();
    }

    function openVm(name) {
        if (!name)
            return;
        Quickshell.execDetached(["virt-viewer", "--connect", "qemu:///system", "--attach", name]);
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
        root.dockerDo(ct.state === "paused" ? "unpause" : "pause", ct.name);
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
        Quickshell.execDetached(["kitty", "--class", "termfloat", "-e", "sh", "-c", "docker exec -it " + name + " bash 2>/dev/null || docker exec -it " + name + " sh"]);
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
            root.busy = false;
            root.lastError = exitCode !== 0 ? (err !== "" ? err : "Command failed") : "";
            if (exitCode === 0)
                root.notify("Lab", tag.replace(":", " "));
            else if (root.lastError)
                root.notify("Lab failed", root.lastError);
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
        command: ["python3", root.ctl, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStdout(text)
        }
    }

    property Timer poll: Timer {
        interval: 4000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    property Timer vpnWatch: Timer {
        interval: 3000
        repeat: false
        onTriggered: root.refresh()
    }

    property Timer settleTimer: Timer {
        interval: 900
        repeat: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
