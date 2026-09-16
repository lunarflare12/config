import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core

// Golden Gate dock: bottom-centered glass tray, hover lift, drag to reorder.
PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    implicitHeight: 200
    exclusiveZone: root.hidden ? 0 : 76
    color: "transparent"

    readonly property bool hidden: Core.Session.gameFullscreenOnScreen(root.screen)
    readonly property bool launchpadCovering: Core.PopupManager.launchpadIntro > 0.01
    visible: !root.hidden && !root.launchpadCovering

    WlrLayershell.namespace: "aurora-dock"
    WlrLayershell.keyboardFocus: dockBar.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Top

    mask: dockBar.menuOpen ? null : dockMask

    property Region dockMask: Region {
        item: dockBar.hitbox
    }

    MouseArea {
        anchors.fill: parent
        enabled: dockBar.menuOpen
        onClicked: dockBar.menuOpen = false
    }

    Item {
        id: escSink
        anchors.fill: parent
        focus: dockBar.menuOpen
        Keys.onEscapePressed: dockBar.menuOpen = false
    }

    DockBar {
        id: dockBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        intro: 1
        interactive: true
        onMenuOpenChanged: {
            if (dockBar.menuOpen)
                escSink.forceActiveFocus();
        }
    }
}
