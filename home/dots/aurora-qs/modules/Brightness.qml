import QtQuick

import Quickshell

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    implicitWidth: 58
    implicitHeight: Core.Theme.moduleHeight

    readonly property var svc: Services.BrightnessService
    readonly property bool menuOpen: Core.PopupManager.isOpen("brightness")

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.menuOpen
    }

    Row {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Core.Icons.forBrightness(root.svc.fraction)
            font.family: Core.Theme.iconFont
            font.pixelSize: Core.Theme.iconSize
            color: root.menuOpen ? Core.Theme.accent : Core.Theme.foreground
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.svc.level + "%"
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSize
            font.weight: Font.Medium
            color: Core.Theme.foreground
            renderType: Text.QtRendering
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function (event) {
            if (event.button === Qt.RightButton) {
                root.svc.cycle();
                return;
            }
            if (event.button === Qt.MiddleButton) {
                root.svc.step(false);
                return;
            }
            const p = root.mapToItem(null, 0, root.height);
            Core.PopupManager.toggle("brightness", p.x + root.width / 2, p.y + Core.Theme.barMarginTop, root);
        }

        onWheel: function (event) {
            if (event.angleDelta.y === 0)
                return;
            root.svc.step(event.angleDelta.y > 0);
        }
    }
}
