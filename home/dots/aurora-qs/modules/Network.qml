import QtQuick

import Quickshell

import "../core" as Core
import "../services" as Services

Item {
    id: root

    implicitWidth: 30
    implicitHeight: Core.Theme.moduleHeight

    readonly property bool menuOpen: Core.PopupManager.isOpen("network")
    readonly property bool connected: Services.NetworkService.ethConnected

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
        text: "\udb80\ude00"
        font.family: Core.Theme.iconFont
        font.pixelSize: Core.Theme.iconSize
        color: root.connected ? Core.Theme.foreground : Core.Theme.foregroundMuted

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuint
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 5
        anchors.rightMargin: 4
        width: 5
        height: 5
        radius: 3
        color: Core.Theme.accent
        opacity: Services.NetworkService.busy ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutQuint
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
            Core.PopupManager.toggle("network", p.x + root.width / 2, p.y + Core.Theme.barMarginTop);
        }
    }

    Binding {
        target: Services.NetworkService
        property: "fastPoll"
        value: root.menuOpen
    }
}
