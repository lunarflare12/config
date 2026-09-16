import QtQuick

import "../core" as Core

Item {
    id: root

    readonly property string kind: Core.OsdController.kind
    readonly property real value: Core.OsdController.value
    readonly property bool muted: Core.OsdController.muted

    implicitWidth: row.implicitWidth
    implicitHeight: Core.Theme.moduleHeight

    readonly property color tint: root.muted ? Core.Theme.danger : Core.Theme.accent
    property real shownValue: root.value

    Behavior on shownValue {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    readonly property string themeName: {
        if (root.kind === "brightness")
            return Core.Icons.brightnessTheme(root.value);
        if (root.kind === "mic")
            return Core.Icons.micTheme(root.muted);
        return Core.Icons.volumeTheme(root.value, root.muted);
    }

    opacity: root.kind !== "" ? 1 : 0
    scale: root.kind !== "" ? 1 : 0.92
    transformOrigin: Item.Center

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
            easing.overshoot: 1.8
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 8

        ThemeIcon {
            id: glyphLabel

            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            name: root.themeName

            onNameChanged: glyphPop.restart()

            SequentialAnimation {
                id: glyphPop
                NumberAnimation {
                    target: glyphLabel
                    property: "scale"
                    to: 1.22
                    duration: 70
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: glyphLabel
                    property: "scale"
                    to: 1.0
                    duration: 180
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.4
                }
            }
        }

        Rectangle {
            id: track

            width: 96
            height: 5
            anchors.verticalCenter: parent.verticalCenter
            radius: 2.5
            color: Core.Theme.surfaceGlass

            Rectangle {
                id: fill

                height: parent.height
                radius: parent.radius
                width: Math.round(track.width * root.shownValue)
                color: root.tint
                antialiasing: true

                Behavior on color {
                    ColorAnimation {
                        duration: Core.Theme.durFast
                        easing.type: Easing.OutQuint
                    }
                }
            }
        }

        Text {
            width: 34
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: root.muted && root.kind !== "brightness" ? "off" : Math.round(root.shownValue * 100) + "%"
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSize
            font.weight: Font.Medium
            color: Core.Theme.foreground
            renderType: Text.QtRendering
        }
    }
}
