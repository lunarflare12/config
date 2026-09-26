import QtQuick

import "../core" as Core

// Frosted toast chrome — shared by overlay cards and the notification centre.
Item {
    id: panel

    property bool critical: false
    property real radius: 18

    Rectangle {
        anchors.fill: parent
        radius: panel.radius
        antialiasing: true
        color: Qt.alpha(Core.Theme.background, 1)
        border.width: 1
        border.color: panel.critical ? Qt.alpha(Core.Theme.danger, 0.7) : Qt.rgba(1, 1, 1, 0.12)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, panel.radius - 1)
        antialiasing: true
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(1, 1, 1, 0.08)
            }
            GradientStop {
                position: 0.45
                color: Qt.rgba(1, 1, 1, 0.02)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0, 0, 0, 0.10)
            }
        }
    }
}
