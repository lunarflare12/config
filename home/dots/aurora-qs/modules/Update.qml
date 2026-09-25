import QtQuick

import "../core" as Core
import "../services" as Services
import "../components" as Components

Item {
    id: root

    implicitWidth: 30
    implicitHeight: Core.Theme.moduleHeight

    readonly property bool running: Services.UpdateService.running

    onRunningChanged: {
        if (!root.running)
            glyph.rotation = 0;
    }

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.running
        activeFill: Qt.alpha(Core.Theme.accent, 0.28)
        feelTarget: glyph
        hoverScale: 1
        pressScale: 1
    }

    Components.ThemeIcon {
        id: glyph
        anchors.centerIn: parent
        name: "update"
        opacity: root.running || mouse.containsMouse ? 1 : 0.92
        scale: 1

        RotationAnimator on rotation {
            running: root.running
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        z: 2
        cursorShape: Qt.PointingHandCursor
        onClicked: Services.UpdateService.start()
    }
}
