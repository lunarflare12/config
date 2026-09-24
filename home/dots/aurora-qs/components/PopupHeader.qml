import QtQuick

import "../core" as Core

// PopupHeader

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property url leadingIcon: ""

    // Toggle switch
    property bool showToggle: false
    property bool toggled: false

    signal toggleRequested

    // Action buttons: [{ icon, tooltip, spinning, action }]
    property var actions: []

    readonly property bool hasText: root.title !== "" || root.subtitle !== ""

    implicitHeight: root.hasText ? 40 : (root.actions.length ? 32 : 0)

    Image {
        id: lead
        visible: root.leadingIcon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        source: root.leadingIcon
        sourceSize.width: 48
        sourceSize.height: 48
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }

    Column {
        visible: root.hasText
        anchors.left: lead.visible ? lead.right : parent.left
        anchors.leftMargin: lead.visible ? 8 : 6
        anchors.right: actionRow.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        spacing: 1

        Text {
            width: parent.width
            visible: root.title !== ""
            text: root.title

            elide: Text.ElideRight

            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeLarge
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering

            color: Core.Theme.foreground
        }

        Text {
            width: parent.width

            visible: root.subtitle !== ""

            text: root.subtitle

            elide: Text.ElideRight

            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            renderType: Text.NativeRendering

            color: Core.Theme.foregroundMuted
        }
    }

    Row {
        id: actionRow

        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter

        spacing: 2

        Repeater {
            model: root.actions

            delegate: Rectangle {
                required property int index
                required property var modelData

                width: 28
                height: 28

                radius: 14
                color: "transparent"

                Tactile {
                    anchors.fill: parent
                    radius: 14
                    hovered: btnMouse.containsMouse
                    pressed: btnMouse.pressed
                    hoverScale: 1.12
                    pressScale: 0.86
                }

                Text {
                    id: btnIcon

                    anchors.centerIn: parent

                    text: modelData.icon

                    font.family: Core.Theme.iconFont
                    font.pixelSize: Core.Theme.iconSizeSmall
                    font.hintingPreference: Font.PreferNoHinting
                    renderType: Text.QtRendering

                    color: Core.Theme.foregroundMuted

                    RotationAnimator on rotation {
                        running: modelData.spinning === true
                        loops: Animation.Infinite

                        from: 0
                        to: 360

                        duration: 1000
                    }
                }

                MouseArea {
                    id: btnMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        const row = root.actions[index];
                        if (row && row.action)
                            row.action();
                    }
                }
            }
        }

        // Toggle switch

        Item {
            visible: root.showToggle

            width: root.showToggle ? 44 : 0
            height: 28

            Rectangle {
                id: track

                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 2

                width: 38
                height: 20

                radius: 10

                color: root.toggled ? Core.Theme.accent : Core.Theme.surface

                border.width: Core.Theme.borderWidth
                border.color: root.toggled ? Core.Theme.accent : Core.Theme.border

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                        easing.type: Easing.OutQuint
                    }
                }

                Rectangle {
                    width: 14
                    height: 14

                    radius: 7

                    anchors.verticalCenter: parent.verticalCenter

                    x: root.toggled ? track.width - width - 3 : 3

                    color: root.toggled ? Core.Theme.accentForeground : Core.Theme.foregroundMuted

                    Behavior on x {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutQuint
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                            easing.type: Easing.OutQuint
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.toggleRequested()
                }
            }
        }
    }
}
