import QtQuick

import "../core" as Core
import "../services" as Services

Rectangle {
    id: root

    property string icon: "disk"
    property color barColor: Core.Theme.accent
    property string label: "/"
    property real usedBytes: 0
    property real totalBytes: 0

    readonly property int percent: totalBytes > 0 ? Math.round(100 * usedBytes / totalBytes) : 0

    visible: root.totalBytes > 0
    implicitHeight: root.visible ? 52 : 0
    radius: Core.Theme.frameRadius
    color: Core.Theme.surface
    border.color: Core.Theme.border
    border.width: Core.Theme.borderWidth

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        Item {
            width: parent.width
            height: 16

            MetricIcon {
                id: diskIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: 14
                height: 14

                name: root.icon
                color: root.barColor
            }

            Text {
                anchors.left: diskIcon.right
                anchors.leftMargin: 6
                anchors.right: percentLabel.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.label + "  " + Services.SystemMonitor.formatBytes(root.usedBytes) + " / " + Services.SystemMonitor.formatBytes(root.totalBytes)
                elide: Text.ElideRight
                color: Core.Theme.foreground
                font.family: Core.Theme.fontFamily
                font.pixelSize: Core.Theme.fontSizeSmall
                font.weight: Font.DemiBold
                renderType: Text.QtRendering
            }

            Text {
                id: percentLabel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.percent + "%"
                color: Core.Theme.foregroundFaint
                font.family: Core.Theme.fontFamily
                font.pixelSize: Core.Theme.fontSizeSmall
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            width: parent.width
            height: Math.max(8, parent.height - 22)
            radius: 4
            color: Qt.rgba(Core.Theme.foreground.r, Core.Theme.foreground.g, Core.Theme.foreground.b, 0.12)

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(1, root.percent / 100.0)) * parent.width
                radius: parent.radius
                color: root.barColor
            }
        }
    }
}
