import QtQuick

import "../core" as Core
import "../services" as Services

// Desktop widget snapped to the shared icon grid. Size is an exact cell span.
Item {
    id: root

    property var host: parent
    property string widgetId: ""
    property int defaultCol: -1
    property int defaultRow: -1
    property int defaultRight: -1
    property int defaultBottom: -1
    property int defaultLeft: -1
    property int defaultTop: -1
    property int spanW: 4
    property int spanH: 4
    property bool framed: true
    property bool fitContent: false
    property bool onDesktop: true
    property Component contentComponent: null

    readonly property var grid: Services.DesktopGrid
    readonly property int cellW: root.host && root.host.cellW > 0 ? root.host.cellW : root.grid.cellW
    readonly property int cellH: root.host && root.host.cellH > 0 ? root.host.cellH : root.grid.cellH
    readonly property bool editing: Core.Session.desktopEdit
    readonly property real contentW: {
        const item = contentLoader.item as Item;
        return item && item.implicitWidth > 0 ? item.implicitWidth : 0;
    }
    readonly property real contentH: {
        const item = contentLoader.item as Item;
        return item && item.implicitHeight > 0 ? item.implicitHeight : 0;
    }
    readonly property int usedSpanW: {
        if (!root.fitContent)
            return Math.max(1, root.spanW);
        return root.grid.spanW(root.contentW + 12, root.cellW);
    }
    readonly property int usedSpanH: {
        if (!root.fitContent)
            return Math.max(1, root.spanH);
        return root.grid.spanH(root.contentH + 12, root.cellH);
    }
    property int col: 0
    property int row: 0
    property bool placed: false
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0

    visible: root.onDesktop
    width: root.fitContent ? Math.max(1, Math.ceil(root.contentW + 12)) : root.usedSpanW * root.cellW
    height: root.fitContent ? Math.max(1, Math.ceil(root.contentH + 12)) : root.usedSpanH * root.cellH
    x: root.dragging ? root.dragX : root.grid.posX(root.col, root.cellW)
    y: root.dragging ? root.dragY : root.grid.posY(root.row, root.cellH)
    z: root.dragging ? 40 : 8

    readonly property string monitorName: root.host && root.host.monitorName ? root.host.monitorName : ""
    readonly property bool gridReady: root.host && root.host.width > 200 && root.host.cols >= 4 && root.monitorName !== ""

    function applySavedOrDefault() {
        if (root.dragging || !root.gridReady || !root.widgetId)
            return;

        const cols = root.host.cols;
        const rows = root.host.rows;
        const saved = Services.DesktopWidgets.get(root.monitorName, root.widgetId);
        if (saved) {
            root.col = root.grid.clampCol(saved.col, root.usedSpanW, cols);
            root.row = root.grid.clampRow(saved.row, root.usedSpanH, rows);
            root.placed = true;
            root.host.place(root.widgetId, root.col, root.row, root.usedSpanW, root.usedSpanH);
            return;
        }

        let col = root.defaultCol;
        let row = root.defaultRow;
        if (col < 0 || row < 0) {
            if (root.defaultLeft >= 0 || root.defaultTop >= 0) {
                col = root.grid.colAt(root.defaultLeft >= 0 ? root.defaultLeft : root.grid.originX, root.cellW);
                row = root.grid.rowAt(root.defaultTop >= 0 ? root.defaultTop : root.grid.originY, root.cellH);
            } else {
                const right = root.defaultRight >= 0 ? root.defaultRight : root.grid.rightPad;
                const bottom = root.defaultBottom >= 0 ? root.defaultBottom : root.grid.bottomPad;
                const x = Math.max(root.grid.originX, root.host.width - right - root.width);
                const y = Math.max(root.grid.originY, root.host.height - bottom - root.height);
                col = root.grid.colAt(x, root.cellW);
                row = root.grid.rowAt(y, root.cellH);
            }
        }

        const snap = root.host.snapTo(col, row, root.usedSpanW, root.usedSpanH, root.widgetId);
        root.col = snap.col;
        root.row = snap.row;
        root.placed = true;
        root.host.place(root.widgetId, root.col, root.row, root.usedSpanW, root.usedSpanH);
        root.savePos();
    }

    function savePos() {
        if (!root.host || !root.widgetId || !root.placed || !root.monitorName)
            return;
        Services.DesktopWidgets.set(root.monitorName, root.widgetId, root.col, root.row);
    }

    onGridReadyChanged: {
        if (root.gridReady)
            Qt.callLater(root.applySavedOrDefault);
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(root.applySavedOrDefault);
        else if (root.host)
            root.host.unplace(root.widgetId);
    }

    onEditingChanged: {
        if (!root.editing && root.dragging) {
            const snap = root.host.snapTo(root.grid.colAt(root.dragX, root.cellW), root.grid.rowAt(root.dragY, root.cellH), root.usedSpanW, root.usedSpanH, root.widgetId);
            root.col = snap.col;
            root.row = snap.row;
            root.placed = true;
            root.dragging = false;
            if (root.host)
                root.host.place(root.widgetId, root.col, root.row, root.usedSpanW, root.usedSpanH);
            root.savePos();
        }
    }

    onUsedSpanWChanged: {
        if (root.placed && root.host)
            root.host.place(root.widgetId, root.col, root.row, root.usedSpanW, root.usedSpanH);
    }
    onUsedSpanHChanged: {
        if (root.placed && root.host)
            root.host.place(root.widgetId, root.col, root.row, root.usedSpanW, root.usedSpanH);
    }

    Component.onCompleted: Qt.callLater(root.applySavedOrDefault)
    Component.onDestruction: {
        if (root.host)
            root.host.unplace(root.widgetId);
    }

    Rectangle {
        id: card

        anchors.fill: parent
        anchors.margins: 6
        radius: 0
        color: root.framed ? Core.Theme.background : "transparent"
        border.width: root.framed ? Core.Theme.borderWidth : 0
        border.color: root.framed ? Core.Theme.borderActive : "transparent"
        clip: root.framed

        Item {
            id: body
            anchors.fill: parent
            anchors.margins: root.framed ? Core.Theme.padding : 0

            Loader {
                id: contentLoader
                // fitContent pins the content top-centre at its implicit size;
                // otherwise it stretches to the whole widget body.
                anchors.fill: root.fitContent ? undefined : parent
                anchors.top: root.fitContent ? parent.top : undefined
                anchors.horizontalCenter: root.fitContent ? parent.horizontalCenter : undefined
                active: root.onDesktop
                asynchronous: true
                sourceComponent: root.contentComponent
                onLoaded: {
                    if (root.fitContent)
                        Qt.callLater(root.applySavedOrDefault);
                }
            }
        }

        MouseArea {
            id: dragHandle

            z: 10
            anchors.fill: parent
            enabled: root.editing
            hoverEnabled: root.editing
            cursorShape: root.editing ? Qt.SizeAllCursor : Qt.ArrowCursor
            preventStealing: true

            property real grabX: 0
            property real grabY: 0

            onPressed: function (mouse) {
                if (!root.editing)
                    return;
                dragHandle.grabX = mouse.x;
                dragHandle.grabY = mouse.y;
                root.dragX = root.x;
                root.dragY = root.y;
                root.dragging = true;
            }

            onPositionChanged: function (mouse) {
                if (!pressed || !root.editing)
                    return;
                root.dragX = Math.round(root.dragX + mouse.x - dragHandle.grabX);
                root.dragY = Math.round(root.dragY + mouse.y - dragHandle.grabY);
            }

            onReleased: {
                if (!root.editing)
                    return;
                const snap = root.host.snapTo(root.grid.colAt(root.dragX, root.cellW), root.grid.rowAt(root.dragY, root.cellH), root.usedSpanW, root.usedSpanH, root.widgetId);
                root.col = snap.col;
                root.row = snap.row;
                root.placed = true;
                root.dragging = false;
                if (root.host)
                    root.host.place(root.widgetId, root.col, root.row, root.usedSpanW, root.usedSpanH);
                root.savePos();
            }
        }
    }
}
