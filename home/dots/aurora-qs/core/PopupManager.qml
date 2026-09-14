pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root
    visible: false

    property string current: ""
    property var anchorScreen: null
    property real anchorCenter: 0
    property real anchorBottom: 0
    property bool contextMenuOpen: false
    property bool dnd: false
    property bool hoverKeep: false
    property string pendingHoverCloseId: ""

    Timer {
        id: hoverCloseTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (!root.hoverKeep && root.current === root.pendingHoverCloseId)
                root.close();
            root.pendingHoverCloseId = "";
        }
    }

    function resolveScreen(fromItem) {
        let n = fromItem;
        while (n) {
            if (n.screen)
                return n.screen;
            n = n.parent;
        }
        const want = (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) || "DP-1";
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0)
            return null;
        for (let i = 0; i < screens.length; i++) {
            const hypr = Hyprland.monitorFor(screens[i]);
            const name = (hypr && hypr.name) ? hypr.name : screens[i].name;
            if (name === want)
                return screens[i];
        }
        return screens[0];
    }

    function isOpen(id) {
        return root.current === id;
    }

    function open(id, center, bottom, fromItem) {
        hoverCloseTimer.stop();
        root.pendingHoverCloseId = "";
        root.anchorCenter = center;
        root.anchorBottom = bottom;
        root.anchorScreen = root.resolveScreen(fromItem);
        root.current = id;
    }

    function toggle(id, center, bottom, fromItem) {
        if (root.current === id) {
            root.close();
            return;
        }

        root.open(id, center, bottom, fromItem);
    }

    function close() {
        hoverCloseTimer.stop();
        root.pendingHoverCloseId = "";
        root.contextMenuOpen = false;
        root.hoverKeep = false;
        root.current = "";
    }

    function requestHoverClose(id) {
        root.pendingHoverCloseId = id;
        hoverCloseTimer.restart();
    }
}
