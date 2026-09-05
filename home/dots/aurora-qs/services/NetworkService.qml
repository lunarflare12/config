pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string ethDevice: ""
    property string ethState: "unavailable"
    property string ethConnection: ""
    property string ethIp: ""
    property string ethSpeed: ""

    readonly property bool ethAvailable: root.ethDevice !== ""
    readonly property bool ethConnected: root.ethState === "connected"
    readonly property string primaryLink: root.ethConnected ? "ethernet" : "none"
    readonly property bool online: root.ethConnected
    readonly property string linkLabel: {
        if (root.ethConnected)
            return root.ethConnection !== "" ? root.ethConnection : "Ethernet";
        if (root.ethAvailable)
            return root.ethState === "unavailable" ? "Unplugged" : "Disconnected";
        return "No ethernet";
    }

    property bool busy: false
    property bool fastPoll: false
    property string lastError: ""
    property string lastLink: ""
    property bool linkPrimed: false

    function notify(summary, body, icon, urgency) {
        Quickshell.execDetached(["notify-send", "-a", "Network", "-i", icon, "-u", urgency, summary, body]);
    }

    function splitFields(line) {
        const out = [];
        let cur = "";

        for (let i = 0; i < line.length; i++) {
            const c = line.charAt(i);

            if (c === "\\" && i + 1 < line.length) {
                cur += line.charAt(i + 1);
                i++;
            } else if (c === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += c;
            }
        }

        out.push(cur);
        return out;
    }

    function queueLinkNotification() {
        root.linkSettleTimer.restart();
    }

    function syncLinkNotification() {
        const now = root.ethConnected
            ? "eth:" + (root.ethConnection !== "" ? root.ethConnection : "Ethernet")
            : (root.ethAvailable ? "none" : "missing");

        if (now === root.lastLink)
            return;

        const prev = root.lastLink;
        root.lastLink = now;

        if (!root.linkPrimed) {
            root.linkPrimed = true;
            return;
        }

        if (now.indexOf("eth:") === 0) {
            root.notify("Ethernet connected", now.substring(4), "network-wired", "low");
            return;
        }

        if (prev.indexOf("eth:") === 0)
            root.notify("Ethernet disconnected", prev.substring(4), "network-wired-disconnected", "normal");
    }

    onEthStateChanged: root.queueLinkNotification()
    onEthConnectionChanged: root.queueLinkNotification()

    property Timer linkSettleTimer: Timer {
        interval: 2500
        repeat: false
        onTriggered: root.syncLinkNotification()
    }

    property Process deviceProc: Process {
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                let ethDev = "";
                let ethSt = "unavailable";
                let ethConn = "";

                for (const line of lines) {
                    if (line.trim() === "")
                        continue;
                    const f = root.splitFields(line);
                    if (f.length < 3)
                        continue;

                    if (f[1] === "ethernet" && ethDev === "") {
                        ethDev = f[0];
                        ethSt = f[2];
                        ethConn = f.length > 3 && f[3] !== "--" ? f[3] : "";
                    }
                }

                root.ethDevice = ethDev;
                root.ethState = ethSt;
                root.ethConnection = ethConn;

                if (ethDev !== "" && ethSt === "connected") {
                    ipProc.command = ["nmcli", "-t", "-f", "IP4.ADDRESS,CAPABILITIES.SPEED", "device", "show", ethDev];
                    ipProc.running = false;
                    ipProc.running = true;
                } else {
                    root.ethIp = "";
                    root.ethSpeed = "";
                }
            }
        }
    }

    property Process ipProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                let ip = "";
                let speed = "";

                for (const line of lines) {
                    if (line.startsWith("IP4.ADDRESS")) {
                        const value = line.split(":", 2)[1] || "";
                        ip = value.split("/")[0];
                    } else if (line.startsWith("CAPABILITIES.SPEED")) {
                        speed = (line.split(":", 2)[1] || "").trim();
                    }
                }

                root.ethIp = ip;
                root.ethSpeed = speed;
            }
        }
    }

    property var actionQueue: []
    property string currentTag: ""

    property Process actionProc: Process {
        id: actionProcImpl

        property string errText: ""

        stdout: StdioCollector {}

        stderr: StdioCollector {
            onStreamFinished: actionProcImpl.errText = text.trim()
        }

        onExited: function (exitCode) {
            const err = actionProcImpl.errText;
            actionProcImpl.errText = "";
            root.currentTag = "";
            root.busy = false;
            root.lastError = exitCode !== 0 ? (err !== "" ? err : "Command failed") : "";
            root.refresh();
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

    function connectEthernet() {
        if (root.ethDevice === "")
            return;
        root.run(["nmcli", "device", "connect", root.ethDevice]);
    }

    function disconnectEthernet() {
        if (root.ethDevice === "")
            return;
        root.run(["nmcli", "device", "disconnect", root.ethDevice]);
    }

    function toggleEthernet() {
        if (root.ethConnected)
            root.disconnectEthernet();
        else
            root.connectEthernet();
    }

    function openEditor() {
        Quickshell.execDetached(["nm-connection-editor"]);
    }

    function refresh() {
        deviceProc.running = false;
        deviceProc.running = true;
    }

    property Timer pollTimer: Timer {
        interval: root.fastPoll ? 2000 : 8000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
