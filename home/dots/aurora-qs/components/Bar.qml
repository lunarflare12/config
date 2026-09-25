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
    exclusiveZone: (root.gameFullscreen || root.hideHold) ? 0 : Core.Theme.barHeight
    color: "#000000"

    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property bool onMain: Core.Session.isDesktopMonitor(root.monitorName)
    property bool gameFullscreen: false
    property int fsWatch: Core.Session.fsTick
    property bool ipcWatch: Core.Session.ipcReady
    onFsWatchChanged: Qt.callLater(root.syncGameFullscreen)
    onIpcWatchChanged: Qt.callLater(root.syncGameFullscreen)
    function syncGameFullscreen() {
        const next = root.ipcWatch && Core.Session.gameFullscreenOnScreen(root.screen);
        if (root.gameFullscreen !== next)
            root.gameFullscreen = next;
    }
    Component.onCompleted: root.syncGameFullscreen()
    property bool hideHold: false
    onGameFullscreenChanged: {
        if (root.gameFullscreen) {
            showDelay.stop();
            root.hideHold = true;
        } else {
            root.hideHold = true;
            showDelay.restart();
        }
    }

    Timer {
        id: showDelay
        interval: 480
        repeat: false
        onTriggered: root.hideHold = false
    }

    // Dock exclusive insets this panel. Pull back over the reserved
    // strip so the menu bar is continuous (no wallpaper hole).
    margins.left: root.onMain && !root.gameFullscreen && !root.hideHold ? -Core.Theme.dockReserve : 0

    visible: !root.gameFullscreen && !root.hideHold

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

                Modules.Update {}

                Modules.Clock {
                    id: clockModule
                    reveal: 1
                }

                Modules.NotificationCenter {}
            }
        }
    }
}
