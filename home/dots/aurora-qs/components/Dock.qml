import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

// Left-edge dock on Xiaomi (DP-1). Hidden on Philips and in fullscreen.
PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    anchors.left: true
    anchors.top: true
    anchors.bottom: true
    margins.top: Core.Theme.barHeight

    implicitWidth: 200
    exclusiveZone: root.onMain && !root.hidden && !root.hideHold ? Core.Theme.dockReserve : 0
    color: "transparent"

    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property bool onMain: Core.Session.isDesktopMonitor(root.monitorName)
    property bool hidden: false
    property int fsWatch: Core.Session.fsTick
    property bool ipcWatch: Core.Session.ipcReady
    onFsWatchChanged: Qt.callLater(root.syncHidden)
    onIpcWatchChanged: Qt.callLater(root.syncHidden)
    function syncHidden() {
        const next = root.ipcWatch && Core.Session.gameFullscreenOnScreen(root.screen);
        if (root.hidden !== next)
            root.hidden = next;
    }
    Component.onCompleted: root.syncHidden()
    readonly property bool launchpadHere: Core.PopupManager.launchpadIntro > 0.01 && root.onMain && Core.Session.focusedMonitorName() === root.monitorName
    property bool hideHold: false
    onHiddenChanged: {
        if (root.hidden) {
            dockShowDelay.stop();
            root.hideHold = true;
        } else {
            root.hideHold = true;
            dockShowDelay.restart();
        }
    }

    Timer {
        id: dockShowDelay
        interval: 480
        repeat: false
        onTriggered: root.hideHold = false
    }

    visible: root.onMain && !root.hidden && !root.hideHold

    property real rise: 1

    WlrLayershell.namespace: "aurora-dock"
    WlrLayershell.keyboardFocus: (dockBar.menuOpen || dockBar.folderOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Top

    mask: {
        if (dockBar.menuOpen || dockBar.folderOpen)
            return null;
        return dockMask;
    }

    property Region dockMask: Region {
        item: dockBar.hitbox
    }

    Behavior on rise {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: dockBar.menuOpen || dockBar.folderOpen
        onClicked: {
            dockBar.menuOpen = false;
            Services.AppsService.closeFolder();
        }
    }

    Item {
        id: escSink
        anchors.fill: parent
        focus: dockBar.menuOpen || dockBar.folderOpen
        Keys.onEscapePressed: {
            dockBar.menuOpen = false;
            Services.AppsService.closeFolder();
        }
    }

    DockBar {
        id: dockBar
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        intro: root.rise
        fadeWithIntro: false
        interactive: !root.launchpadHere
        opacity: root.launchpadHere ? 0 : 1
        onMenuOpenChanged: {
            if (dockBar.menuOpen)
                escSink.forceActiveFocus();
        }
        onLaunched: Core.PopupManager.close()
    }
}
