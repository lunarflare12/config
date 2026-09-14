import QtQuick

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    implicitWidth: Math.max(44, row.implicitWidth + 8)
    implicitHeight: Core.Theme.moduleHeight

    readonly property bool menuOpen: Core.PopupManager.isOpen("cpu")
    readonly property int temp: Services.SystemMonitor.temperature
    readonly property color valueColor: {
        if (root.temp >= 85)
            return Core.Theme.error;
        if (root.temp >= 70)
            return Core.Theme.warning;
        return root.menuOpen ? Core.Theme.accent : Core.Theme.foreground;
    }

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.menuOpen
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Components.MetricIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: Core.Theme.iconSize
            height: Core.Theme.iconSize
            name: "temp"
            color: root.valueColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.temp >= 0 ? root.temp + "°C" : "—"
            color: root.valueColor
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            font.weight: Font.Medium
            renderType: Text.QtRendering
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: {
            const p = root.mapToItem(null, 0, root.height);
            Core.PopupManager.toggle("cpu", p.x + root.width / 2, p.y + Core.Theme.barMarginTop, root);
        }
    }
}
