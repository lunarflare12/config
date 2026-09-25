import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../core" as Core

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property var hyprMon: Hyprland.monitorFor(root.screen)
    readonly property real monX: root.hyprMon ? Number(root.hyprMon.x) : (root.screen ? root.screen.x : 0)
    readonly property real monY: root.hyprMon ? Number(root.hyprMon.y) : (root.screen ? root.screen.y : 0)
    readonly property bool picking: Core.Session.screenshotOpen
    readonly property bool editing: Core.Session.sattyOpen
    readonly property bool catching: root.picking || root.editing
    readonly property color dimColor: Qt.rgba(0, 0, 0, 0.42)

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
        return Qt.rect(box.x - root.monX - 8, box.y - root.monY - 8, box.w + 16, box.h + 16);
    }
    readonly property bool hasHole: root.hole.width >= 2 && root.hole.height >= 2
    readonly property int hx: Math.floor(root.hole.x)
    readonly property int hy: Math.floor(root.hole.y)
    readonly property int hw: Math.ceil(root.hole.width)
    readonly property int hh: Math.ceil(root.hole.height)

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusiveZone: -1
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.catching

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
            x: root.hx
            y: root.hy
            width: root.editing ? Math.max(0, root.hw) : 0
            height: root.editing ? Math.max(0, root.hh) : 0
        }
    }

    mask: root.catching ? root.activeMask : root.emptyMask

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
        Core.Session.captureRegion(root.monX + box.x, root.monY + box.y, box.width, box.height);
    }

    Item {
        id: catcher
        anchors.fill: parent
        focus: root.picking

        Keys.onEscapePressed: root.dismiss()

        Rectangle {
            anchors.fill: parent
            color: root.picking && !root.hasHole ? root.dimColor : Qt.rgba(0, 0, 0, 0)
        }

        Rectangle {
            x: 0
            y: 0
            width: catcher.width
            height: Math.max(0, root.hy)
            color: root.dimColor
            visible: root.picking && root.hasHole
        }

        Rectangle {
            x: 0
            y: root.hy
            width: Math.max(0, root.hx)
            height: Math.max(0, root.hh)
            color: root.dimColor
            visible: root.picking && root.hasHole
        }

        Rectangle {
            x: root.hx + root.hw
            y: root.hy
            width: Math.max(0, catcher.width - x)
            height: Math.max(0, root.hh)
            color: root.dimColor
            visible: root.picking && root.hasHole
        }

        Rectangle {
            x: 0
            y: root.hy + root.hh
            width: catcher.width
            height: Math.max(0, catcher.height - y)
            color: root.dimColor
            visible: root.picking && root.hasHole
        }

        Rectangle {
            visible: root.picking && root.hasHole
            x: root.hx
            y: root.hy
            width: root.hw
            height: root.hh
            color: "transparent"
            border.width: 1
            border.color: Core.Theme.borderActive
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.catching
            hoverEnabled: false
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: root.picking ? Qt.CrossCursor : Qt.ArrowCursor
            onPressed: function (mouse) {
                if (root.editing || mouse.button !== Qt.LeftButton) {
                    root.dismiss();
                    return;
                }
                root.x0 = root.x1 = mouse.x;
                root.y0 = root.y1 = mouse.y;
                root.dragging = false;
            }
            onPositionChanged: function (mouse) {
                if (root.editing || !pressed || !(mouse.buttons & Qt.LeftButton))
                    return;
                root.x1 = mouse.x;
                root.y1 = mouse.y;
                if (!root.dragging && Math.hypot(root.x1 - root.x0, root.y1 - root.y0) >= 2)
                    root.dragging = true;
            }
            onReleased: function (mouse) {
                if (root.editing || mouse.button !== Qt.LeftButton)
                    return;
                root.x1 = mouse.x;
                root.y1 = mouse.y;
                if (root.dragging)
                    root.commit();
                else
                    root.dragging = false;
            }
            onCanceled: root.dismiss()
        }
    }
}
