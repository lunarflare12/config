import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../core" as Core

PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property bool onFocused: {
        const mon = Hyprland.focusedMonitor;
        if (!mon || !root.screen)
            return true;
        return mon.name === root.screen.name;
    }

    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    implicitHeight: 120
    exclusiveZone: 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: Core.Session.screenshotOpen && root.onFocused && !Core.Session.gameFullscreenOnScreen(root.screen)

    WlrLayershell.namespace: "aurora-screenshot"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: delayed
        interval: 90
        repeat: false
        property string mode: "region"
        onTriggered: Core.Session.runScreenshot(delayed.mode)
    }

    function pick(mode) {
        delayed.mode = mode;
        Core.Session.screenshotOpen = false;
        delayed.restart();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Core.Session.screenshotOpen = false
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: row.implicitWidth + 28
        height: 72
        radius: 20
        color: "transparent"
        border.width: Core.Theme.borderWidth
        border.color: Core.Theme.border
        antialiasing: true

        Glass {
            anchors.fill: parent
            radius: parent.radius
            strength: 0.9
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: [
                    { mode: "output", label: "Screen", icon: Core.Icons.computer },
                    { mode: "window", label: "Window", icon: Core.Icons.overview },
                    { mode: "region", label: "Selection", icon: Core.Icons.crop }
                ]

                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    width: 108
                    height: 56
                    radius: 14
                    color: mouse.containsMouse ? Core.Theme.surfaceGlassHover : "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.modelData.icon
                            font.family: Core.Theme.iconFont
                            font.pixelSize: 18
                            color: Core.Theme.text
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.modelData.label
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: Core.Theme.fontSizeSmall
                            color: Core.Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function (event) {
                            event.accepted = true;
                            root.pick(btn.modelData.mode);
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: Core.Session.screenshotOpen = false
    }
}
