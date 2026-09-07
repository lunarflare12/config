import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property bool onFocused: {
        const mon = Hyprland.focusedMonitor;
        if (!mon || !root.screen)
            return true;
        return mon.name === root.screen.name;
    }

    readonly property bool hidden: Core.Session.gameFullscreenOnScreen(root.screen) || !root.onFocused

    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    implicitHeight: 92
    exclusiveZone: root.hidden ? 0 : 84
    color: "transparent"
    visible: !root.hidden

    WlrLayershell.namespace: "aurora-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property var pinHints: [
        { hints: ["launcher"], kind: "launcher", label: "Launchpad" },
        { hints: ["thunar", "nautilus", "dolphin"], kind: "app", label: "Files" },
        { hints: ["kitty", "alacritty", "foot"], kind: "app", label: "Terminal" },
        { hints: ["firefox", "google-chrome", "zen", "chromium"], kind: "app", label: "Browser" },
        { hints: ["steam"], kind: "app", label: "Steam" },
        { hints: ["telegram"], kind: "app", label: "Telegram" },
        { hints: ["obsidian"], kind: "app", label: "Obsidian" },
        { hints: ["cursor", "code-cursor", "code"], kind: "app", label: "Cursor" },
        { hints: ["screenshot"], kind: "screenshot", label: "Screenshot" },
        { hints: ["overview"], kind: "overview", label: "Mission Control" }
    ]

    function findEntry(hints) {
        const entries = Services.AppsService.entries || [];
        for (let h = 0; h < hints.length; h++) {
            const hint = hints[h].toLowerCase();
            for (let i = 0; i < entries.length; i++) {
                const e = entries[i];
                const id = String(e.id || "").toLowerCase();
                const name = String(e.name || "").toLowerCase();
                const cls = String(e.startupClass || "").toLowerCase();
                if (id.indexOf(hint) !== -1 || name.indexOf(hint) !== -1 || cls.indexOf(hint) !== -1)
                    return e;
            }
        }
        return null;
    }

    function classKey(cls) {
        return String(cls || "").toLowerCase().replace(/[^a-z0-9]+/g, "");
    }

    function runningByClass() {
        const map = {};
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const cls = String(ipc.class || ipc.initialClass || "");
            if (!cls)
                continue;
            const key = root.classKey(cls);
            if (!map[key])
                map[key] = [];
            map[key].push(t);
        }
        return map;
    }

    function pinMatchesClass(pin, cls) {
        const c = String(cls || "").toLowerCase();
        for (let i = 0; i < pin.hints.length; i++) {
            if (c.indexOf(pin.hints[i]) !== -1)
                return true;
        }
        const entry = root.findEntry(pin.hints);
        if (!entry)
            return false;
        const id = String(entry.id || "").toLowerCase();
        const start = String(entry.startupClass || "").toLowerCase();
        return c.indexOf(start) !== -1 || id.indexOf(root.classKey(c)) !== -1;
    }

    readonly property var items: {
        const running = root.runningByClass();
        const used = {};
        const out = [];
        for (let i = 0; i < root.pinHints.length; i++) {
            const pin = root.pinHints[i];
            let windows = [];
            const keys = Object.keys(running);
            for (let k = 0; k < keys.length; k++) {
                const wins = running[keys[k]];
                if (wins.length && root.pinMatchesClass(pin, (wins[0].lastIpcObject || {}).class || keys[k])) {
                    windows = windows.concat(wins);
                    used[keys[k]] = true;
                }
            }
            out.push({
                kind: pin.kind,
                label: pin.label,
                entry: pin.kind === "app" ? root.findEntry(pin.hints) : null,
                windows: windows,
                hints: pin.hints
            });
        }
        const extraKeys = Object.keys(running);
        for (let e = 0; e < extraKeys.length; e++) {
            if (used[extraKeys[e]])
                continue;
            const wins = running[extraKeys[e]];
            const ipc = wins[0].lastIpcObject || {};
            const cls = String(ipc.class || extraKeys[e]);
            out.push({
                kind: "running",
                label: cls,
                entry: root.findEntry([cls]),
                windows: wins,
                hints: [cls]
            });
        }
        return out;
    }

    function activateItem(item) {
        if (item.kind === "launcher") {
            Hyprland.dispatch("exec qs ipc call launcher toggle");
            return;
        }
        if (item.kind === "overview") {
            Core.Session.toggleOverview();
            return;
        }
        if (item.kind === "screenshot") {
            Core.Session.toggleScreenshot();
            return;
        }
        const wins = item.windows || [];
        if (wins.length) {
            const active = Hyprland.activeToplevel;
            const activeAddr = active ? active.address : "";
            let next = wins[0];
            for (let i = 0; i < wins.length; i++) {
                if (wins[i].address === activeAddr) {
                    next = wins[(i + 1) % wins.length];
                    break;
                }
            }
            const ipc = next.lastIpcObject || {};
            const ws = next.workspace ? Number(next.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (ws)
                Hyprland.dispatch("workspace " + ws);
            if (next.wayland && typeof next.wayland.activate === "function")
                next.wayland.activate();
            else if (next.address)
                Hyprland.dispatch("focuswindow address:" + next.address);
            return;
        }
        if (item.entry)
            Services.AppsService.launch(item.entry);
    }

    Item {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        width: dockBody.width
        height: dockBody.height

        Rectangle {
            id: dockBody
            width: row.implicitWidth + 28
            height: 76
            radius: 22
            color: "transparent"
            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.border
            antialiasing: true

            Glass {
                anchors.fill: parent
                radius: parent.radius
                strength: 0.82
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: root.items

                    delegate: Item {
                        id: slot
                        required property var modelData
                        property real mag: mouse.containsMouse ? 1.28 : 1.0
                        width: 56 * mag
                        height: 64
                        Behavior on width {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutBack
                            }
                        }

                        Image {
                            id: icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            width: 44 * slot.mag
                            height: 44 * slot.mag
                            asynchronous: true
                            sourceSize.width: 128
                            sourceSize.height: 128
                            visible: slot.modelData.entry && slot.modelData.entry.icon
                            source: slot.modelData.entry ? Quickshell.iconPath(slot.modelData.entry.icon, "application-x-executable") : ""
                            Behavior on width {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on height {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutBack
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 14
                            visible: !icon.visible
                            text: slot.modelData.kind === "launcher" ? Core.Icons.launchpad : (slot.modelData.kind === "overview" ? Core.Icons.overview : (slot.modelData.kind === "screenshot" ? Core.Icons.camera : Core.Icons.forApp(slot.modelData.label)))
                            font.family: Core.Theme.iconFont
                            font.pixelSize: 26 * slot.mag
                            color: Core.Theme.text
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            width: 4
                            height: 4
                            radius: 2
                            visible: slot.modelData.windows && slot.modelData.windows.length > 0
                            color: Core.Theme.text
                            opacity: 0.85
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activateItem(slot.modelData)
                        }
                    }
                }
            }
        }
    }
}
