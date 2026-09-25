import QtQuick

import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../modules" as Modules

// Brain Shell notches: workspaces left, island center, status right.
PanelWindow {
    id: root

    property var modelData: null

    screen: root.modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Core.Theme.notchHeight
    exclusiveZone: (root.gameFullscreen || root.hideHold) ? 0 : Core.Theme.notchHeight
    color: "transparent"

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

    visible: !root.gameFullscreen && !root.hideHold

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aurora-bar"
    WlrLayershell.keyboardFocus: tray.menuOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool osd: Core.OsdController.active

    readonly property bool networkOpen: Core.PopupManager.isOpen("network")
    readonly property bool brightnessOpen: Core.PopupManager.isOpen("brightness")
    readonly property bool audioOpen: Core.PopupManager.isOpen("audio")
    readonly property bool calendarOpen: Core.PopupManager.isOpen("calendar")
    readonly property bool rightDrawer: root.networkOpen || root.brightnessOpen || root.audioOpen
    readonly property int lWidth: Math.max(Core.Theme.lNotchMinWidth, Math.min(Core.Theme.lNotchMaxWidth, leftRow.implicitWidth + Core.Theme.notchPadding * 2))
    property int cWidth: root.calendarOpen ? Core.Theme.centerSheetWidth : Math.max(Core.Theme.cNotchMinWidth, Math.min(Core.Theme.cNotchMaxWidth, island.implicitWidth + Core.Theme.notchPadding))

    Behavior on cWidth {
        NumberAnimation {
            duration: Core.Theme.animDuration
            easing.type: Easing.InOutCubic
        }
    }
    property int rWidth: {
        if (root.networkOpen || root.brightnessOpen || root.audioOpen)
            return Core.Theme.rightSheetWidth;
        const raw = Math.max(Core.Theme.rNotchMinWidth, Math.min(Core.Theme.rNotchMaxWidth, rightRow.implicitWidth + Core.Theme.notchPadding * 2));
        const budget = root.width - root.lWidth - root.cWidth - Core.Theme.notchGap * 2;
        return Math.max(Core.Theme.rNotchMinWidth, Math.min(raw, budget));
    }

    Behavior on rWidth {
        NumberAnimation {
            duration: Core.Theme.animDuration
            easing.type: Easing.InOutCubic
        }
    }

    SeamlessBarShape {
        id: barShape
        anchors.fill: parent
        leftWidth: root.lWidth
        centerWidth: root.cWidth
        rightWidth: root.rWidth
    }

    Item {
        id: leftNotch
        width: root.lWidth
        height: Core.Theme.notchHeight
        anchors.left: parent.left

        Row {
            id: leftRow
            anchors.centerIn: parent
            spacing: 8

            ThemeIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "nix"
                width: 22
                height: 22
                sourceSize.width: 88
                sourceSize.height: 88
                smooth: true

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Core.PopupManager.toggle("launcher")
                }
            }

            Modules.Workspaces {
                id: workspacesModule
                screen: root.screen
                from: 1
                span: 6
            }

            Modules.Tray {
                id: tray
                barWindow: root
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Item {
        id: centerNotch
        width: root.cWidth
        height: Core.Theme.notchHeight
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        Text {
            anchors.centerIn: parent
            text: "▾"
            color: Core.Theme.accent
            font.pixelSize: 14
            opacity: root.calendarOpen ? 1 : 0
            visible: opacity > 0
            z: 2
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -12
                enabled: root.calendarOpen
                cursorShape: Qt.PointingHandCursor
                onClicked: Core.PopupManager.close()
            }
        }

        CenterIsland {
            id: island
            anchors.centerIn: parent
            screen: root.screen
            osd: root.osd
            opacity: root.calendarOpen ? 0 : 1
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }

    Item {
        id: rightNotch
        width: root.rWidth
        height: Core.Theme.notchHeight
        anchors.right: parent.right
        clip: true

        Text {
            anchors.centerIn: parent
            text: "▾"
            color: Core.Theme.accent
            font.pixelSize: 14
            opacity: root.rightDrawer ? 1 : 0
            visible: opacity > 0
            z: 2
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -12
                enabled: root.rightDrawer
                cursorShape: Qt.PointingHandCursor
                onClicked: Core.PopupManager.close()
            }
        }

        Row {
            id: rightRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Core.Theme.notchPadding
            spacing: 6
            opacity: root.rightDrawer ? 0 : 1
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
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

            Modules.Workspaces {
                screen: root.screen
                from: 7
                span: 6
            }

            Modules.NotificationCenter {}
        }
    }
}
