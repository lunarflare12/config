import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property bool picking: Core.Session.screenshotOpen
    readonly property bool editing: Core.Session.sattyOpen && !root.picking
    readonly property bool hot: root.picking || root.editing
    readonly property color dimColor: Qt.rgba(0, 0, 0, root.picking ? 0.36 : 0.46)

    property bool dragging: false
    property real x0: 0
    property real y0: 0
    property real x1: 0
    property real y1: 0
    readonly property rect dragBox: {
        const x = Math.min(root.x0, root.x1);
        const y = Math.min(root.y0, root.y1);
        return Qt.rect(x, y, Math.abs(root.x1 - root.x0), Math.abs(root.y1 - root.y0));
    }
    readonly property rect hole: {
        if (root.picking && root.dragging && root.dragBox.width >= 2 && root.dragBox.height >= 2)
            return root.dragBox;
        const box = Core.Session.sattyBox;
        if (!root.editing || !box)
            return Qt.rect(0, 0, 0, 0);
        const sx = root.screen ? root.screen.x : 0;
        const sy = root.screen ? root.screen.y : 0;
        return Qt.rect(box.x - sx - 8, box.y - sy - 8, box.w + 16, box.h + 16);
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusiveZone: 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: true

    WlrLayershell.namespace: "aurora-screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.picking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property Region emptyMask: Region {
        width: 0
        height: 0
    }

    property Region activeMask: Region {
        item: catcher
        Region {
            intersection: Intersection.Subtract
            x: Math.round(root.hole.x)
            y: Math.round(root.hole.y)
            width: root.editing ? Math.max(0, Math.round(root.hole.width)) : 0
            height: root.editing ? Math.max(0, Math.round(root.hole.height)) : 0
        }
    }

    mask: root.hot ? root.activeMask : root.emptyMask

    onPickingChanged: {
        root.dragging = false;
        root.x0 = root.y0 = root.x1 = root.y1 = 0;
    }

    function dismiss() {
        root.dragging = false;
        Core.Session.dismissScreenshot();
    }

    function commit() {
        const box = root.dragBox;
        root.dragging = false;
        if (box.width < 8 || box.height < 8) {
            root.dismiss();
            return;
        }
        const sx = root.screen ? root.screen.x : 0;
        const sy = root.screen ? root.screen.y : 0;
        Core.Session.captureRegion(sx + box.x, sy + box.y, box.width, box.height);
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: root.picking
        Keys.onEscapePressed: root.dismiss()

        Rectangle {
            visible: root.picking && !root.dragging
            anchors.fill: parent
            color: root.dimColor
        }

        Rectangle {
            visible: root.hot && root.hole.width >= 2
            x: 0
            y: 0
            width: catcher.width
            height: Math.max(0, root.hole.y)
            color: root.dimColor
        }

        Rectangle {
            visible: root.hot && root.hole.width >= 2
            x: 0
            y: root.hole.y
            width: Math.max(0, root.hole.x)
            height: Math.max(0, root.hole.height)
            color: root.dimColor
        }

        Rectangle {
            visible: root.hot && root.hole.width >= 2
            x: root.hole.x + root.hole.width
            y: root.hole.y
            width: Math.max(0, catcher.width - x)
            height: Math.max(0, root.hole.height)
            color: root.dimColor
        }

        Rectangle {
            visible: root.hot && root.hole.width >= 2
            x: 0
            y: root.hole.y + root.hole.height
            width: catcher.width
            height: Math.max(0, catcher.height - y)
            color: root.dimColor
        }

        Rectangle {
            visible: root.picking && root.dragging && root.dragBox.width >= 2
            x: root.dragBox.x
            y: root.dragBox.y
            width: root.dragBox.width
            height: root.dragBox.height
            color: "transparent"
            border.width: 1
            border.color: Core.Theme.borderActive
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: root.picking ? Qt.CrossCursor : Qt.ArrowCursor
            onPressed: function (mouse) {
                if (!root.picking || mouse.button !== Qt.LeftButton) {
                    root.dismiss();
                    return;
                }
                root.x0 = root.x1 = mouse.x;
                root.y0 = root.y1 = mouse.y;
                root.dragging = true;
            }
            onPositionChanged: function (mouse) {
                if (!root.dragging)
                    return;
                root.x1 = mouse.x;
                root.y1 = mouse.y;
            }
            onReleased: function (mouse) {
                if (!root.dragging)
                    return;
                root.x1 = mouse.x;
                root.y1 = mouse.y;
                root.commit();
            }
            onCanceled: root.dismiss()
        }
    }
}
