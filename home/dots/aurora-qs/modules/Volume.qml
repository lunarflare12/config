import QtQuick

import "../components" as Components
import "../core" as Core
import "../services" as Services

// Volume (bar module)

Item {
    id: root

    property bool iconOnly: false

    implicitWidth: root.iconOnly ? 28 : 58
    implicitHeight: Core.Theme.moduleHeight

    readonly property var svc: Services.AudioService

    readonly property bool menuOpen: Core.PopupManager.isOpen("audio")

    Components.Tactile {
        anchors.fill: parent
        hovered: mouse.containsMouse
        pressed: mouse.pressed
        active: root.menuOpen
    }

    Row {
        anchors.centerIn: parent

        spacing: 5

        Components.ThemeIcon {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            name: Core.Icons.volumeTheme(root.svc.volume, root.svc.muted || !root.svc.sink)

            Behavior on opacity {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuint
                }
            }

            opacity: root.svc.muted ? 0.55 : 1

            onNameChanged: popAnim.restart()

            SequentialAnimation {
                id: popAnim

                NumberAnimation {
                    target: icon
                    property: "scale"
                    to: 1.2
                    duration: 70
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: icon
                    property: "scale"
                    to: 1.0
                    duration: 160
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.iconOnly

            text: root.svc.volumePercent + "%"

            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSize
            font.weight: Font.Medium

            color: root.svc.muted ? Core.Theme.foregroundMuted : Core.Theme.foreground

            renderType: Text.QtRendering
        }
    }

    // Small badge in the corner while the microphone is muted, so you can tell at a glance without opening anything.
    Rectangle {
        id: micBadge

        anchors.right: parent.right
        anchors.rightMargin: 1
        anchors.top: parent.top
        anchors.topMargin: 2

        width: 8
        height: 8

        radius: 4

        color: Core.Theme.danger

        visible: root.svc.source !== null && root.svc.micMuted

        scale: visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutQuint
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function (event) {
            if (event.button === Qt.RightButton) {
                root.svc.toggleOutputMute();
                return;
            }

            if (event.button === Qt.MiddleButton) {
                root.svc.toggleMicMute();
                return;
            }

            // Bar coordinates -> screen coordinates. Only x is
            // used; the popup derives its own y from the theme.
            const p = root.mapToItem(null, 0, root.height);

            Core.PopupManager.toggle("audio", p.x + root.width / 2, p.y + Core.Theme.barMarginTop, root);
        }

        onWheel: function (event) {
            const step = 0.05;

            root.svc.stepVolume(root.svc.sink, event.angleDelta.y > 0 ? step : -step);
        }
    }
}
