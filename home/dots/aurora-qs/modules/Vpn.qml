import QtQuick

import "../components" as Components
import "../core" as Core
import "../services" as Services

Item {
    id: root

    implicitWidth: row.implicitWidth + 10
    implicitHeight: Core.Theme.moduleHeight

    readonly property bool up: Services.LabService.vpnUp
    readonly property string label: Services.LabService.vpnLabel
    readonly property color ink: root.up ? Core.Theme.success : Core.Theme.error

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Item {
            width: 18
            height: 18
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: Qt.alpha(root.ink, root.up ? 0.16 : 0.34)
            }

            Text {
                anchors.centerIn: parent
                text: Core.Icons.shield
                font.family: Core.Theme.iconFont
                font.pixelSize: Core.Theme.iconSize
                color: root.ink
                renderType: Text.NativeRendering
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.up && root.label.length > 0
            text: root.label
            color: root.ink
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
            renderType: Text.QtRendering
        }
    }
}