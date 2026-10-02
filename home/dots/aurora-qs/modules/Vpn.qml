import QtQuick

import "../components" as Components
import "../core" as Core
import "../services" as Services

// Leftmost chip in the right bar cluster: lock + active profile name.
Item {
    id: root

    implicitWidth: Math.ceil(row.implicitWidth + 12)
    implicitHeight: Core.Theme.moduleHeight

    readonly property var svc: Services.LabService
    readonly property bool on: root.svc.vpnUp
    readonly property string profile: root.svc.activeVpn
    readonly property color ink: root.on ? Core.Theme.success : Core.Theme.danger

    Component.onCompleted: root.svc.retain()
    Component.onDestruction: root.svc.release()

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.on
        activeFill: Qt.alpha(root.ink, 0.22)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: root.on ? Core.Icons.lock : Core.Icons.lockOpen
            font.family: Core.Theme.iconFont
            font.pixelSize: Core.Theme.iconSizeMedium
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering
            color: root.ink

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuint
                }
            }

            onTextChanged: popAnim.restart()

            SequentialAnimation {
                id: popAnim

                NumberAnimation {
                    target: glyph
                    property: "scale"
                    to: 1.18
                    duration: 80
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: glyph
                    property: "scale"
                    to: 1.0
                    duration: 160
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.8
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.on && root.profile.length > 0
            text: root.profile
            color: root.ink
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSize
            font.weight: Font.DemiBold
            renderType: Text.QtRendering
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
    }
}
