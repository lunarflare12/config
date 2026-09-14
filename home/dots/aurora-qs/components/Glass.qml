import QtQuick

import "../core" as Core

Item {
    id: glass
    property real radius: 0
    property real strength: 1.0

    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        antialiasing: true
        opacity: glass.strength
        color: Core.Theme.background
    }
}
