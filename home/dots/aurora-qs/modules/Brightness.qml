import QtQuick

import "../components" as Components
import "../core" as Core
import "../services" as Services

Item {
    id: root

    property bool iconOnly: false

    implicitWidth: root.iconOnly ? 28 : 58
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

        Components.ThemeIcon {
            id: sun

            anchors.verticalCenter: parent.verticalCenter
            name: Core.Icons.brightnessTheme(root.svc.fraction)

            onNameChanged: sunPop.restart()

            SequentialAnimation {
                id: sunPop
                NumberAnimation {
                    target: sun
                    property: "scale"
                    to: 1.18
                    duration: 80
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: sun
                    property: "scale"
                    to: 1.0
                    duration: 160
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.iconOnly
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
