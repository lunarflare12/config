import QtQuick

import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../modules" as Modules

// macOS menu bar: Arch + app on the left, status extras + clock on the right.
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
    color: "#000000"

    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property bool gameFullscreen: Core.Session.gameFullscreenOnScreen(root.screen)

    visible: !root.gameFullscreen

    WlrLayershell.namespace: "aurora-bar"
    WlrLayershell.keyboardFocus: tray.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool osd: Core.OsdController.active

    Rectangle {
        id: surface

        anchors.fill: parent
        color: "#000000"

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
            width: Math.max(workspacesModule.implicitWidth, osdView.implicitWidth)
            height: Core.Theme.moduleHeight

            Modules.Workspaces {
                id: workspacesModule
                anchors.centerIn: parent
                screen: root.screen
                opacity: root.osd || osdView.opacity > 0.01 ? 0 : 1
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }
            }

            BarOsd {
                id: osdView
                anchors.centerIn: parent
            }
        }

        Item {
            id: rightCluster

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 12

            width: rightRow.implicitWidth
            height: Core.Theme.moduleHeight

            Row {
                id: rightRow
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                Modules.Tray {
                    id: tray
                    barWindow: root
                }

                Modules.DesktopEdit {}

                Modules.Volume {
                    iconOnly: true
                }

                Modules.Brightness {
                    iconOnly: true
                }

                Modules.Network {
                    iconOnly: true
                }

                Modules.Clock {
                    id: clockModule
                    reveal: 1
                }
            }
        }
    }
}
