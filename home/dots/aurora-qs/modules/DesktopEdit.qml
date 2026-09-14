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

    Text {
        anchors.centerIn: parent
        text: Core.Icons.pencil
        font.family: Core.Theme.iconFont
        font.pixelSize: Core.Theme.iconSize
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.QtRendering
        color: root.on ? Core.Theme.accent : Core.Theme.foreground
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Core.Session.toggleDesktopEdit()
    }
}
