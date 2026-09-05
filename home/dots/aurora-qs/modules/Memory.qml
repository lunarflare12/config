import QtQuick

import "../core" as Core
import "../services" as Services

Item {
    id: root

    implicitWidth: 30
    implicitHeight: Core.Theme.moduleHeight

    readonly property bool menuOpen: Core.PopupManager.isOpen("memory")

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.menuOpen ? Core.Theme.surfaceGlass : mouse.containsMouse ? Core.Theme.surfaceGlassHover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 120
                easing.type: Easing.OutQuint
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "󰍛"
        font.family: Core.Theme.iconFont
        font.pixelSize: Core.Theme.iconSize
        color: Core.Theme.foreground
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: {
            const p = root.mapToItem(null, 0, root.height);
            Core.PopupManager.toggle("memory", p.x + root.width / 2, p.y + Core.Theme.barMarginTop);
        }
    }
}
