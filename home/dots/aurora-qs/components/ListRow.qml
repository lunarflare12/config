import QtQuick

import "../core" as Core

// ListRow

Rectangle {
    id: root

    property string icon: ""
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property string trailingName: ""
    property string actionLabel: ""

    property color iconColor: Core.Theme.foreground
    property color trailingColor: Core.Theme.foregroundMuted

    property bool active: false
    property bool glassActive: false
    property bool busy: false
    property bool dimmed: false

    // Right-click gives window-space coordinates for the menu
    signal activated
    signal contextRequested(real mx, real my)

    implicitHeight: root.subtitle !== "" ? Core.Theme.rowHeight : 34

    radius: Core.Theme.radiusRow

    color: "transparent"

    Tactile {
        anchors.fill: parent
        radius: root.radius
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.active
        hoverScale: 1.02
        pressScale: 0.95
    }

    opacity: root.dimmed ? 0.45 : 1.0

    Behavior on opacity {
        NumberAnimation {
            duration: Core.Theme.durFast
            easing.type: Easing.OutQuint
        }
    }

    // Active indicator bar

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        anchors.leftMargin: 3

        width: 3
        height: root.active ? parent.height * 0.5 : 0

        radius: 2

        color: Core.Theme.accent

        Behavior on height {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuint
            }
        }
    }

    // Leading icon

    Item {
        id: iconText

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter

        width: 20
        height: 20

        opacity: root.busy ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuint
            }
        }

        MetricIcon {
            anchors.centerIn: parent

            width: 18
            height: 18

            visible: root.iconName !== ""

            name: root.iconName
            color: root.active ? Core.Theme.accent : root.iconColor
        }

        Text {
            anchors.centerIn: parent

            visible: root.iconName === ""

            text: root.icon

            font.family: Core.Theme.iconFont
            font.pixelSize: Core.Theme.iconSize
            font.hintingPreference: Font.PreferNoHinting
            renderType: Text.QtRendering

            color: root.active ? Core.Theme.accent : root.iconColor

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuint
                }
            }
        }
    }

    // Busy spinner (replaces the icon)

    Text {
        anchors.centerIn: iconText

        text: "\udb81\udd1e"

        font.family: Core.Theme.iconFont
        font.pixelSize: Core.Theme.iconSize
        font.hintingPreference: Font.PreferNoHinting
        renderType: Text.QtRendering

        color: Core.Theme.accent

        opacity: root.busy ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuint
            }
        }

        RotationAnimator on rotation {
            running: root.busy
            loops: Animation.Infinite

            from: 0
            to: 360

            duration: 900
        }
    }

    // Title + subtitle

    Column {
        anchors.left: iconText.right
        anchors.leftMargin: 10
        anchors.right: trailingText.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        spacing: 1

        Text {
            width: parent.width

            text: root.title

            elide: Text.ElideRight

            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSize
            font.weight: root.active ? Font.DemiBold : Font.Medium
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

            color: root.active ? Core.Theme.accent : Core.Theme.foregroundMuted
        }
    }

    // Trailing badge

    Item {
        id: trailingText

        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter

        width: {
            if (root.actionLabel !== "")
                return Math.max(16, actionLabelText.implicitWidth);
            if (root.trailingName !== "" || root.trailing !== "")
                return 16;
            return 0;
        }
        height: 16

        MetricIcon {
            anchors.fill: parent

            visible: root.actionLabel === "" && root.trailingName !== ""

            name: root.trailingName
            color: root.trailingColor
        }

        Text {
            id: actionLabelText
            anchors.centerIn: parent
            visible: root.actionLabel !== ""
            text: root.actionLabel
            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
            color: root.trailingColor
        }

        Text {
            anchors.centerIn: parent

            visible: root.actionLabel === "" && root.trailingName === "" && root.trailing !== ""

            text: root.trailing

            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            renderType: Text.QtRendering

            color: root.trailingColor
        }
    }

    // Interaction

    MouseArea {
        id: mouse

        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function (event) {
            if (event.button === Qt.RightButton) {
                const p = mouse.mapToItem(null, event.x, event.y);

                root.contextRequested(p.x, p.y);
                return;
            }

            root.activated();
        }
    }
}
