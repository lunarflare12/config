import QtQuick
import QtQuick.Shapes

import "../core" as Core

// Circular stroke spinner. Icon-font rotation looks like tofu / a broken glyph.
Item {
    id: root

    property bool running: false
    property color color: Core.Theme.accent
    property real stroke: 2.2

    implicitWidth: 16
    implicitHeight: 16
    visible: root.running
    opacity: root.running ? 1 : 0

    Shape {
        id: ring
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeWidth: root.stroke
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: Math.max(1, (Math.min(ring.width, ring.height) - root.stroke) / 2)
                radiusY: Math.max(1, (Math.min(ring.width, ring.height) - root.stroke) / 2)
                startAngle: -80
                sweepAngle: 240
            }
        }

        RotationAnimator on rotation {
            running: root.running && root.visible
            loops: Animation.Infinite
            duration: 720
            from: 0
            to: 360
        }
    }
}
