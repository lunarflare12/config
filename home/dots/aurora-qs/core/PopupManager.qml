pragma Singleton

import QtQuick

Item {
    id: root
    visible: false

    property string current: ""
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

    function isOpen(id) {
        return root.current === id;
    }

    function open(id, center, bottom) {
        hoverCloseTimer.stop();
        root.pendingHoverCloseId = "";
        root.anchorCenter = center;
        root.anchorBottom = bottom;
        root.current = id;
    }

    function toggle(id, center, bottom) {
        if (root.current === id) {
            root.close();
            return;
        }

        root.open(id, center, bottom);
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
