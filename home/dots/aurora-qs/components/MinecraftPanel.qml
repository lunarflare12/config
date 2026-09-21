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
        color: Qt.rgba(0.10, 0.10, 0.12, 0.92)
        border.width: 1
        border.color: panel.critical ? Qt.rgba(1, 0.35, 0.35, 0.55) : Qt.rgba(1, 1, 1, 0.14)
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
