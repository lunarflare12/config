import QtQuick

import "../core" as Core
import "../components" as Components

Item {
    id: root

    implicitWidth: 30
    implicitHeight: Core.Theme.moduleHeight

    readonly property bool on: Core.Session.desktopEdit

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.on
        activeFill: Qt.alpha(Core.Theme.accent, 0.28)
    }

    Components.ThemeIcon {
        anchors.centerIn: parent
        name: "edit"
        opacity: root.on ? 1 : 0.92
        scale: root.on ? 1.08 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Core.Session.toggleDesktopEdit()
    }
}
