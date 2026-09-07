import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../core" as Core

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: Core.Session.overviewOpen && !Core.Session.gameFullscreenOnScreen(root.screen)

    onVisibleChanged: {
        if (root.visible)
            Core.PopupManager.close();
    }

    WlrLayershell.namespace: "aurora-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var hyprMonitor: Hyprland.monitorFor(root.screen)
    readonly property int monitorW: root.hyprMonitor ? root.hyprMonitor.width : (root.screen ? root.screen.width : 1920)
    readonly property int monitorH: root.hyprMonitor ? root.hyprMonitor.height : (root.screen ? root.screen.height : 1080)
    readonly property int monitorX: root.hyprMonitor ? root.hyprMonitor.x : 0
    readonly property int monitorY: root.hyprMonitor ? root.hyprMonitor.y : 0

    readonly property var spaces: {
        const occupied = {};
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const ws = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (ws >= 1 && ws <= 10)
                occupied[ws] = true;
        }
        const focused = Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) : 1;
        occupied[focused] = true;
        const ids = Object.keys(occupied).map(function (k) { return Number(k); }).sort(function (a, b) { return a - b; });
        if (ids.length === 0)
            ids.push(1);
        return ids;
    }

    function windowsOn(ws) {
        const out = [];
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id !== ws)
                continue;
            if (root.hyprMonitor && t.monitor && t.monitor.name && t.monitor.name !== root.hyprMonitor.name)
                continue;
            out.push(t);
        }
        return out;
    }

    function closeOverview() {
        Core.Session.overviewOpen = false;
    }

    function activateSpace(ws) {
        root.closeOverview();
        Hyprland.dispatch("workspace " + ws);
    }

    function activateWindow(t) {
        if (!t)
            return;
        const ipc = t.lastIpcObject || {};
        const ws = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
        root.closeOverview();
        if (ws)
            Hyprland.dispatch("workspace " + ws);
        if (t.wayland && typeof t.wayland.activate === "function")
            t.wayland.activate();
        else if (t.address)
            Hyprland.dispatch("focuswindow address:" + t.address);
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.42)
        opacity: root.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeOverview()
        }
    }

    Column {
        id: layout
        anchors.centerIn: parent
        spacing: 18
        width: Math.min(parent.width - 80, parent.width * 0.92)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Mission Control"
            color: Core.Theme.text
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeLarge
            font.weight: Font.DemiBold
        }

        Grid {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            columns: Math.min(5, Math.max(1, root.spaces.length))
            spacing: 16
            property int cardW: Math.floor((layout.width - (grid.columns - 1) * grid.spacing) / grid.columns)
            property real scale: Math.min(grid.cardW / Math.max(1, root.monitorW), 280 / Math.max(1, root.monitorH))

            Repeater {
                model: root.spaces

                delegate: Item {
                    id: card
                    required property var modelData
                    readonly property int workspace: Number(card.modelData)
                    readonly property bool focused: Hyprland.focusedWorkspace && Number(Hyprland.focusedWorkspace.id) === card.workspace
                    readonly property var wins: root.windowsOn(card.workspace)
                    width: grid.cardW
                    height: Math.round(root.monitorH * grid.scale) + 28

                    Rectangle {
                        id: desk
                        width: Math.round(root.monitorW * grid.scale)
                        height: Math.round(root.monitorH * grid.scale)
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 12
                        color: Qt.rgba(Core.Theme.background.r, Core.Theme.background.g, Core.Theme.background.b, 0.88)
                        border.width: card.focused ? 2 : 1
                        border.color: card.focused ? Core.Theme.accent : Core.Theme.border
                        clip: true
                        antialiasing: true

                        Glass {
                            anchors.fill: parent
                            radius: parent.radius
                            strength: 0.55
                        }

                        Repeater {
                            model: card.wins

                            delegate: Item {
                                id: win
                                required property var modelData
                                readonly property var ipc: win.modelData.lastIpcObject || {}
                                readonly property var at: win.ipc.at || [0, 0]
                                readonly property var size: win.ipc.size || [320, 240]
                                x: Math.max(0, (Number(win.at[0]) - root.monitorX) * grid.scale)
                                y: Math.max(0, (Number(win.at[1]) - root.monitorY) * grid.scale)
                                width: Math.max(28, Number(win.size[0]) * grid.scale)
                                height: Math.max(20, Number(win.size[1]) * grid.scale)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: Core.Theme.surface
                                    border.width: 1
                                    border.color: Core.Theme.border
                                    clip: true

                                    ScreencopyView {
                                        id: preview
                                        anchors.fill: parent
                                        captureSource: root.visible ? win.modelData.wayland : null
                                        live: false
                                        visible: preview.hasContent
                                        onCaptureSourceChanged: {
                                            if (captureSource)
                                                preview.captureFrame();
                                        }
                                        onVisibleChanged: {
                                            if (root.visible && captureSource)
                                                preview.captureFrame();
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !preview.hasContent
                                        text: Core.Icons.forApp(String(win.ipc.class || win.modelData.title || ""))
                                        font.family: Core.Theme.iconFont
                                        font.pixelSize: Math.min(22, win.height * 0.4)
                                        color: Core.Theme.textMuted
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function (mouse) {
                                        mouse.accepted = true;
                                        root.activateWindow(win.modelData);
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: root.activateSpace(card.workspace)
                        }
                    }

                    Text {
                        anchors.top: desk.bottom
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Desktop " + card.workspace
                        color: card.focused ? Core.Theme.accent : Core.Theme.textSecondary
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: Core.Theme.fontSizeSmall
                        font.weight: card.focused ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: root.closeOverview()
        Keys.onReturnPressed: root.closeOverview()
    }
}
