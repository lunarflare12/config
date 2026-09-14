import QtQuick

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    implicitWidth: chip.implicitWidth + 8
    implicitHeight: Core.Theme.moduleHeight

    readonly property bool menuOpen: Core.PopupManager.isOpen("memory")
    readonly property int used: Services.SystemMonitor.memory
    readonly property color valueColor: {
        if (root.used >= 90)
            return Core.Theme.error;
        if (root.used >= 80)
            return Core.Theme.warning;
        return root.menuOpen ? Core.Theme.accent : Core.Theme.foreground;
    }

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.menuOpen
    }

    Components.ResourceChip {
        id: chip
        anchors.centerIn: parent
        iconName: "ram"
        percent: root.used
        ink: root.valueColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: {
            const p = root.mapToItem(null, 0, root.height);
            Core.PopupManager.toggle("memory", p.x + root.width / 2, p.y + Core.Theme.barMarginTop, root);
        }
    }
}
