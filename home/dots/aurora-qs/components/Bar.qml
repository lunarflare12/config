import QtQuick

import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../modules" as Modules

// Full-width top bar. The layer surface is only as tall as the bar — a 600px
// host (old pill+launcher window) made Hyprland blur a 2560x666 quad every
// frame, which on NVIDIA blanks/kills other windows.
PanelWindow {
    id: root

    property var modelData: null

    screen: root.modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Core.Theme.barHeight
    exclusiveZone: root.gameFullscreen ? 0 : Core.Theme.barHeight
    color: "transparent"

    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property bool gameFullscreen: Core.Session.gameFullscreenOnScreen(root.screen)

    visible: !root.gameFullscreen

    WlrLayershell.namespace: "aurora-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool osd: Core.OsdController.active

    Rectangle {
        id: surface

        anchors.fill: parent
        color: "transparent"

        Glass {
            anchors.fill: parent
            radius: 0
        }

        Item {
            id: leftCluster

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14

            width: leftRow.implicitWidth
            height: Core.Theme.moduleHeight

            Row {
                id: leftRow
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                Modules.AppName {
                    id: appName
                }
            }
        }

        Item {
            id: centerCluster

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(centerRow.implicitWidth, osdView.implicitWidth)
            height: Core.Theme.moduleHeight

            Row {
                id: centerRow
                anchors.centerIn: parent
                spacing: 14
                opacity: root.osd ? 0 : 1
                visible: opacity > 0.01

                Modules.Workspaces {
                    id: workspacesModule
                    screen: root.screen
                }

                Modules.Clock {
                    id: clockModule
                    reveal: 1
                }
            }

            BarOsd {
                id: osdView
                anchors.centerIn: parent
                opacity: root.osd ? 1 : 0
                visible: opacity > 0.01
            }
        }

        Item {
            id: rightCluster

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 14

            width: rightRow.implicitWidth
            height: Core.Theme.moduleHeight

            Row {
                id: rightRow
                spacing: 10
                anchors.verticalCenter: parent.verticalCenter

                Modules.DesktopEdit {}

                Modules.Network {}

                Modules.Cpu {}

                Modules.Memory {}

                Modules.Shader {
                    screen: root.screen
                }

                Modules.NotificationCenter {
                    id: notificationCenter
                }

                Modules.Tray {
                    id: tray
                    barWindow: root
                }
            }
        }
    }
}
