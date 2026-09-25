import QtQuick
import Quickshell.Hyprland

import "../core" as Core

// Brain Shell capsule dots. Left half 1-6, right half 7-12.
Rectangle {
    id: root

    property var screen: null
    property int from: 1
    property int span: 6

    readonly property int total: Core.Session.workspacesPerMonitor
    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property int base: Core.Session.monitorIndex(root.monitorName) * Core.Session.workspacesPerMonitor
    readonly property int activeGlobal: {
        const _ = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values.length : 0;
        const __ = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0;
        return Core.Session.activeWorkspaceOnMonitor(root.monitorName);
    }
    readonly property int activeLocal: {
        const id = root.activeGlobal;
        if (!(id >= 1))
            return 1;
        return ((id - 1) % root.total) + 1;
    }

    color: Core.Theme.wsBackground
    radius: Core.Theme.wsRadius
    implicitWidth: workspaceRow.width + Core.Theme.wsPadding * 2
    implicitHeight: Core.Theme.wsDotSize + Core.Theme.wsPadding * 2
    width: implicitWidth
    height: implicitHeight

    property bool scrollBusy: false

    Timer {
        id: scrollCooldown
        interval: 280
        repeat: false
        onTriggered: root.scrollBusy = false
    }

    function occupiedAt(localWs) {
        if (localWs < 1 || localWs > root.total)
            return false;
        const _ = Core.Session.clientsTick;
        return Core.Session.windowsOnWorkspace(root.base + localWs).length > 0;
    }

    function focusLocal(localWs) {
        if (Core.Session.overviewOpen)
            Core.Session.overviewOpen = false;
        Core.Session.focusLocalWorkspace(root.monitorName, localWs);
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function (event) {
            if (root.scrollBusy)
                return;
            root.scrollBusy = true;
            scrollCooldown.restart();
            const first = root.from;
            const last = root.from + root.span - 1;
            let next = root.activeLocal;
            if (next < first || next > last)
                next = first;
            if (event.angleDelta.y < 0)
                next = next >= last ? first : next + 1;
            else
                next = next <= first ? last : next - 1;
            root.focusLocal(next);
        }
    }

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: Core.Theme.wsSpacing

        Repeater {
            model: root.span

            delegate: Rectangle {
                id: dot

                required property int index
                readonly property int localWs: root.from + dot.index
                readonly property int workspace: root.base + dot.localWs
                readonly property bool focused: root.activeLocal === dot.localWs
                readonly property bool occupied: root.occupiedAt(dot.localWs)

                height: Core.Theme.wsDotSize
                radius: height / 2
                width: dot.focused ? Core.Theme.wsActiveWidth : Core.Theme.wsDotSize
                color: dot.focused ? Core.Theme.wsActive : (dot.occupied ? Core.Theme.wsOccupied : Core.Theme.wsEmpty)

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 200
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (event) {
                        if (event.button === Qt.RightButton) {
                            Core.Session.toggleOverview();
                            return;
                        }
                        root.focusLocal(dot.localWs);
                    }
                }
            }
        }
    }
}
