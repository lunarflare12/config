import QtQuick

import Quickshell

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Core.Theme.moduleHeight

    readonly property bool menuOpen: Core.PopupManager.isOpen("network")
    readonly property bool connected: Services.NetworkService.ethConnected
    readonly property color ink: root.connected ? Core.Theme.foreground : Core.Theme.foregroundMuted

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.menuOpen
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Components.MetricIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: Core.Theme.iconSize
            height: Core.Theme.iconSize
            name: "ethernet"
            color: root.ink
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Components.MetricIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                name: "download"
                color: root.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.SystemMonitor.downloadRate
                color: root.ink
                font.family: Core.Theme.fontFamily
                font.pixelSize: Core.Theme.fontSizeSmall
                font.weight: Font.Medium
                renderType: Text.QtRendering
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Components.MetricIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                name: "upload"
                color: root.ink
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Services.SystemMonitor.uploadRate
                color: root.ink
                font.family: Core.Theme.fontFamily
                font.pixelSize: Core.Theme.fontSizeSmall
                font.weight: Font.Medium
                renderType: Text.QtRendering
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function (event) {
            if (event.button === Qt.MiddleButton) {
                Services.NetworkService.toggleEthernet();
                return;
            }

            if (event.button === Qt.RightButton) {
                Services.NetworkService.openEditor();
                return;
            }

            const p = root.mapToItem(null, 0, root.height);
            Core.PopupManager.toggle("network", p.x + root.width / 2, p.y + Core.Theme.barMarginTop, root);
        }
    }

    Binding {
        target: Services.NetworkService
        property: "fastPoll"
        value: root.menuOpen
    }
}
