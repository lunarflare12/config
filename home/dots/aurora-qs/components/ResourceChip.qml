import QtQuick
import QtQuick.Shapes

import "../core" as Core

Item {
    id: root

    property string iconName: "ram"
    property int percent: 0
    property color ink: Core.Theme.foreground

    implicitWidth: row.implicitWidth
    implicitHeight: Core.Theme.moduleHeight

    readonly property real clamped: Math.max(0, Math.min(100, root.percent))

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Item {
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter

            Shape {
                anchors.fill: parent

                ShapePath {
                    strokeColor: Qt.alpha(root.ink, 0.22)
                    strokeWidth: 2.2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: 10
                        centerY: 10
                        radiusX: 7.2
                        radiusY: 7.2
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                ShapePath {
                    strokeColor: root.ink
                    strokeWidth: 2.2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: 10
                        centerY: 10
                        radiusX: 7.2
                        radiusY: 7.2
                        startAngle: -90
                        sweepAngle: root.clamped * 3.6
                    }
                }
            }

            MetricIcon {
                anchors.centerIn: parent
                width: 9
                height: 9
                name: root.iconName
                color: root.ink
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.clamped + "%"
            color: root.ink
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            font.weight: Font.Medium
            renderType: Text.QtRendering
        }
    }
}
