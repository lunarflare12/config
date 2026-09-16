import QtQuick

import Quickshell
import Quickshell.Hyprland

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    property var screen: null

    readonly property int cell: 26
    readonly property int pill: 22
    readonly property int count: Core.Session.workspacesPerMonitor
    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property int base: Core.Session.monitorIndex(root.monitorName) * Core.Session.workspacesPerMonitor
    readonly property int activeGlobal: {
        const _ = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values.length : 0;
        const __ = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0;
        return Core.Session.activeWorkspaceOnMonitor(root.monitorName);
    }
    readonly property var spaceLocals: {
        const _ = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0;
        const __ = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values.length : 0;
        const ___ = root.activeGlobal;
        const ____ = Core.Session.spaceOrder;
        const _____ = Core.Session.spaceRev;
        const list = Core.Session.workspaceLocalsOnMonitor(root.monitorName);
        return list.length ? list : [1];
    }
    readonly property int activeLocal: {
        const id = root.activeGlobal;
        if (!(id >= 1))
            return 1;
        return ((id - 1) % root.count) + 1;
    }
    readonly property int activeIndex: {
        const list = root.spaceLocals;
        const id = root.activeLocal;
        for (let i = 0; i < list.length; i++) {
            if (list[i] === id)
                return i;
        }
        return 0;
    }
    readonly property real destX: root.activeIndex * root.cell + (root.cell - root.pill) / 2

    property real pillX: 0
    property real pillW: 22
    property bool pillReady: false

    implicitWidth: root.cell * Math.max(1, root.spaceLocals.length)
    implicitHeight: Core.Theme.moduleHeight

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    function flowTo(toX) {
        flowAnim.stop();
        const fromX = root.pillX;
        const fromW = root.pillW;
        const toW = root.pill;
        const left = Math.min(fromX, toX);
        const right = Math.max(fromX + fromW, toX + toW);
        const stretch = Math.max(toW, right - left);

        stretchX.from = fromX;
        stretchX.to = left;
        stretchW.from = fromW;
        stretchW.to = stretch;
        settleX.from = left;
        settleX.to = toX;
        settleW.from = stretch;
        settleW.to = toW;
        flowAnim.start();
    }

    onDestXChanged: {
        if (!root.pillReady) {
            root.pillX = root.destX;
            root.pillW = root.pill;
            return;
        }
        if (Math.abs(root.destX - root.pillX) < 0.5 && Math.abs(root.pillW - root.pill) < 0.5)
            return;
        root.flowTo(root.destX);
    }

    Component.onCompleted: {
        root.pillX = root.destX;
        root.pillW = root.pill;
        Qt.callLater(function () {
            root.pillReady = true;
        });
    }

    SequentialAnimation {
        id: flowAnim

        ParallelAnimation {
            NumberAnimation {
                id: stretchX
                target: root
                property: "pillX"
                duration: 140
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: stretchW
                target: root
                property: "pillW"
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            NumberAnimation {
                id: settleX
                target: root
                property: "pillX"
                duration: 180
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                id: settleW
                target: root
                property: "pillW"
                duration: 180
                easing.type: Easing.InOutCubic
            }
        }
    }

    function windowsOn(globalId) {
        const out = [];
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id !== globalId)
                continue;
            out.push(t);
        }
        return out;
    }

    function occupiedAt(localWs) {
        if (localWs < 1 || localWs > root.count)
            return false;
        const _ = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0;
        return root.windowsOn(root.base + localWs).length > 0;
    }

    function iconToplevel(wins) {
        let best = null;
        let bestScore = -1;
        for (let i = 0; i < wins.length; i++) {
            const t = wins[i];
            const ipc = t.lastIpcObject || {};
            const cls = String(ipc.class || ipc.initialClass || "").toLowerCase();
            if (cls.indexOf("crashmailer") !== -1 || cls.indexOf("steamwebhelper") !== -1)
                continue;
            const size = ipc.size || [0, 0];
            let score = Number(size[0]) * Number(size[1]);
            if (cls.indexOf("gamescope") !== -1 || cls.indexOf("steam_app_") !== -1)
                score += 1000000000;
            if (cls.indexOf("minecraft") !== -1)
                score += 1000000000;
            if (score > bestScore) {
                bestScore = score;
                best = t;
            }
        }
        return best || (wins.length ? wins[0] : null);
    }

    // Occupied track sits behind the active pill so consecutive desks
    // stay one capsule, including the focused workspace.
    Row {
        anchors.centerIn: parent
        spacing: 0
        z: 0

        Repeater {
            model: root.spaceLocals.length

            delegate: Item {
                id: track

                required property int index

                readonly property int localWs: root.spaceLocals[track.index]
                readonly property bool occupied: root.occupiedAt(track.localWs)
                readonly property int prevLocal: track.index > 0 ? root.spaceLocals[track.index - 1] : 0
                readonly property int nextLocal: track.index < root.spaceLocals.length - 1 ? root.spaceLocals[track.index + 1] : 0
                readonly property bool prevOccupied: track.prevLocal === track.localWs - 1 && root.occupiedAt(track.prevLocal)
                readonly property bool nextOccupied: track.nextLocal === track.localWs + 1 && root.occupiedAt(track.nextLocal)

                width: root.cell
                height: root.pill

                Rectangle {
                    anchors.fill: parent
                    color: track.occupied ? Qt.alpha(Core.Theme.accent, 0.32) : "transparent"
                    topLeftRadius: track.prevOccupied ? 0 : root.pill / 2
                    topRightRadius: track.nextOccupied ? 0 : root.pill / 2
                    bottomLeftRadius: track.prevOccupied ? 0 : root.pill / 2
                    bottomRightRadius: track.nextOccupied ? 0 : root.pill / 2
                }
            }
        }
    }

    Rectangle {
        id: activePill

        x: root.pillX
        y: Math.round((parent.height - height) / 2)
        width: root.pillW
        height: root.pill
        radius: height / 2
        color: Core.Theme.accent
        z: 1
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0
        z: 2

        Repeater {
            model: root.spaceLocals.length

            delegate: Item {
                id: cell

                required property int index

                readonly property int localWs: root.spaceLocals[cell.index]
                readonly property int workspace: root.base + cell.localWs
                readonly property var windows: {
                    const _ = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0;
                    return root.windowsOn(cell.workspace);
                }
                readonly property bool occupied: cell.windows.length > 0
                readonly property bool focused: root.activeGlobal === cell.workspace
                readonly property string iconSource: {
                    if (cell.windows.length === 0)
                        return "";
                    return Services.AppsService.iconPathForWindow(root.iconToplevel(cell.windows));
                }

                width: root.cell
                height: root.pill

                Components.Tactile {
                    anchors.fill: parent
                    radius: root.pill / 2
                    hovered: cellMouse.containsMouse
                    pressed: cellMouse.pressed
                    active: cell.focused
                    hoverScale: 1.14
                    pressScale: 0.84
                    activeFill: "transparent"
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 5
                    height: 5
                    radius: 2.5
                    visible: !cell.occupied
                    color: cell.focused ? Core.Theme.accentForeground : Core.Theme.textMuted
                    scale: cell.focused ? 1.15 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Image {
                    id: appIcon
                    width: 14
                    height: 14
                    anchors.centerIn: parent
                    visible: cell.occupied && status === Image.Ready
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectFit
                    source: cell.iconSource
                    mipmap: true
                    smooth: true
                    scale: cell.focused ? 1.08 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.6
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: cell.occupied && appIcon.status !== Image.Ready
                    text: (cell.index + 1) === 10 ? "0" : String(cell.index + 1)
                    color: cell.focused ? Core.Theme.accentForeground : Core.Theme.text
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: cell.focused ? Font.DemiBold : Font.Medium
                    renderType: Text.QtRendering
                }

                MouseArea {
                    id: cellMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (event) {
                        if (event.button === Qt.RightButton) {
                            Core.Session.toggleOverview();
                            return;
                        }
                        Core.Session.focusLocalWorkspace(root.monitorName, cell.localWs);
                    }
                }
            }
        }
    }
}
