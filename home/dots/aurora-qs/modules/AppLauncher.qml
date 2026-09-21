import QtQuick
import "../components" as Components
import "../core" as Core
import "../services" as Services

// Android-style vertical app drawer with macOS Launchpad folders.
Components.LauncherView {
    id: launcher

    launcherId: "launcher"
    promptIcon: Core.Icons.search
    placeholder: "Search"
    launchpad: true
    vimNavigation: false

    columns: 7
    pageRows: 5
    cardWidth: 680

    property int dragFrom: -1
    property int hoverSlot: -1
    property real dragX: 0
    property real dragY: 0
    property Item dockTarget: null
    property bool flowLock: false
    property bool mergeDrop: false
    property var folderDragApp: null
    property int folderDragFrom: -1
    property int folderHoverSlot: -1
    readonly property bool dragging: launcher.dragFrom >= 0
    readonly property bool folderDragging: launcher.folderDragApp !== null
    readonly property bool searching: !!(launcher.query && launcher.query.trim().length)
    readonly property var openFolder: Services.AppsService.openFolder

    handleEscape: function () {
        if (Services.AppsService.openFolderId) {
            Services.AppsService.closeFolder();
            return true;
        }
        return false;
    }

    onDragFromChanged: Services.AppsService.launchpadDragging = launcher.dragFrom >= 0
    onFolderDraggingChanged: Services.AppsService.launchpadDragging = launcher.folderDragging || launcher.dragFrom >= 0
    onDidClose: {
        launcher.folderDragApp = null;
        launcher.folderDragFrom = -1;
        launcher.folderHoverSlot = -1;
        Services.AppsService.closeFolder();
    }

    readonly property var results: {
        if (!launcher.searching)
            return Services.AppsService.launchpadTiles;
        const apps = Services.AppsService.search(launcher.query);
        const out = [];
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            out.push({
                "type": "app",
                "id": e && e.id ? String(e.id) : "",
                "name": Services.AppsService.displayName(e),
                "entry": e,
                "apps": []
            });
        }
        return out;
    }
    itemCount: launcher.results.length

    function flowIndexFor(i) {
        const from = launcher.dragFrom;
        const to = launcher.hoverSlot;
        if (!launcher.dragging || from < 0 || to < 0 || from === to)
            return i;
        if (i === from)
            return to;
        if (from < to) {
            if (i > from && i <= to)
                return i - 1;
        } else if (i >= to && i < from) {
            return i + 1;
        }
        return i;
    }

    function resetDrag() {
        launcher.flowLock = true;
        launcher.dragFrom = -1;
        launcher.hoverSlot = -1;
        launcher.mergeDrop = false;
        launcher.folderDragApp = null;
        launcher.folderDragFrom = -1;
        launcher.folderHoverSlot = -1;
        Services.AppsService.clearDockDrop();
        Qt.callLater(function () {
            launcher.flowLock = false;
        });
    }

    function commitDrag() {
        const from = launcher.dragFrom;
        const to = launcher.hoverSlot;
        const merge = launcher.mergeDrop;
        const overDock = Services.AppsService.dockDropActive;
        const slot = Services.AppsService.dockHoverSlot;
        const entry = from >= 0 ? launcher.results[from] : null;
        launcher.flowLock = true;
        launcher.dragFrom = -1;
        launcher.hoverSlot = -1;
        launcher.mergeDrop = false;
        if (overDock)
            Services.AppsService.pinDock(entry && entry.id, slot);
        else if (merge && from >= 0 && to >= 0)
            Services.AppsService.mergeLaunchpad(from, to);
        else if (from >= 0 && to >= 0)
            Services.AppsService.moveLaunchpad(from, to);
        Services.AppsService.clearDockDrop();
        Qt.callLater(function () {
            launcher.flowLock = false;
        });
    }

    onAccepted: {
        if (launcher.dragging)
            return;
        const entry = launcher.results[launcher.selectedIndex];
        if (!entry)
            return;
        if (entry.type === "folder") {
            Services.AppsService.toggleFolder(entry.id);
            return;
        }
        Services.AppsService.launch(entry);
        launcher.dismiss();
    }

    contentComponent: Component {
        Item {
            id: stage

            readonly property int cellW: Math.max(110, Math.min(170, Math.floor((width - 120) / launcher.columns)))
            readonly property int cellH: Math.max(118, Math.min(168, Math.round(stage.cellW * 1.12)))
            readonly property int rows: Math.max(1, Math.ceil(Math.max(1, launcher.itemCount) / launcher.columns))

            function slotAtGrid(gx, gy) {
                if (stage.cellW <= 0 || stage.cellH <= 0)
                    return -1;
                const col = Math.max(0, Math.min(launcher.columns - 1, Math.floor(gx / stage.cellW)));
                const row = Math.max(0, Math.floor(gy / stage.cellH));
                const global = row * launcher.columns + col;
                if (global < 0)
                    return 0;
                if (global >= launcher.itemCount)
                    return Math.max(0, launcher.itemCount - 1);
                return global;
            }

            function overIcon(gx, gy, index) {
                if (index < 0)
                    return false;
                const col = index % launcher.columns;
                const row = Math.floor(index / launcher.columns);
                const cx = (col + 0.5) * stage.cellW;
                const cy = (row + 0.5) * stage.cellH;
                const dx = gx - cx;
                const dy = gy - cy;
                const hit = 28;
                return dx * dx + dy * dy < hit * hit;
            }

            Timer {
                id: edgeScroll
                interval: 16
                repeat: true
                property int dir: 0
                onTriggered: {
                    if (!launcher.dragging || edgeScroll.dir === 0)
                        return;
                    const next = scroller.contentY + edgeScroll.dir * 24;
                    scroller.contentY = Math.max(0, Math.min(Math.max(0, scroller.contentHeight - scroller.height), next));
                }
            }

            function trackEdge(py) {
                let dir = 0;
                if (py < 48)
                    dir = -1;
                else if (py > scroller.height - 48)
                    dir = 1;
                if (dir === 0) {
                    edgeScroll.stop();
                    edgeScroll.dir = 0;
                    return;
                }
                edgeScroll.dir = dir;
                if (!edgeScroll.running)
                    edgeScroll.start();
            }

            function trackDock(item, mx, my) {
                const dock = launcher.dockTarget;
                let overDock = false;
                if (dock) {
                    const d = item.mapToItem(dock, mx, my);
                    overDock = dock.containsApps ? dock.containsApps(d.x, d.y) : (d.x >= -24 && d.x <= dock.width + 24 && d.y >= -28 && d.y <= dock.height + 28);
                    Services.AppsService.dockDropActive = overDock;
                    if (overDock)
                        Services.AppsService.dockHoverSlot = dock.slotAt(d.x, d.y);
                } else {
                    Services.AppsService.dockDropActive = false;
                }
                return overDock;
            }

            function folderSlotAt(item, mx, my) {
                const g = item.mapToItem(folderGrid, mx, my);
                if (folderLayer.cellW <= 0 || folderLayer.cellH <= 0)
                    return -1;
                const col = Math.max(0, Math.min(folderLayer.folderCols - 1, Math.floor(g.x / folderLayer.cellW)));
                const row = Math.max(0, Math.floor(g.y / folderLayer.cellH));
                const i = row * folderLayer.folderCols + col;
                if (i < 0)
                    return 0;
                if (i >= folderLayer.folderCount)
                    return Math.max(0, folderLayer.folderCount - 1);
                return i;
            }

            function folderFlowIndexFor(i) {
                const from = launcher.folderDragFrom;
                const to = launcher.folderHoverSlot;
                if (!launcher.folderDragging || from < 0 || to < 0 || from === to)
                    return i;
                if (i === from)
                    return to;
                if (from < to) {
                    if (i > from && i <= to)
                        return i - 1;
                } else if (i >= to && i < from) {
                    return i + 1;
                }
                return i;
            }

            function finishFolderDrag(item, mx, my) {
                const app = launcher.folderDragApp;
                const from = launcher.folderDragFrom;
                const folderId = launcher.openFolder ? launcher.openFolder.id : "";
                const overDock = Services.AppsService.dockDropActive;
                const slot = Services.AppsService.dockHoverSlot;
                const s = item.mapToItem(sheet, mx, my);
                const inSheet = s.x >= 0 && s.y >= 0 && s.x <= sheet.width && s.y <= sheet.height;
                const dest = stage.folderSlotAt(item, mx, my);
                launcher.folderDragApp = null;
                launcher.folderDragFrom = -1;
                launcher.folderHoverSlot = -1;
                if (app && overDock)
                    Services.AppsService.pinDock(app.id, slot);
                else if (app && folderId && !inSheet)
                    Services.AppsService.removeFromFolder(folderId, app.id);
                else if (app && folderId && inSheet && from >= 0 && dest >= 0)
                    Services.AppsService.moveInFolder(folderId, from, dest);
                Services.AppsService.clearDockDrop();
            }

            Flickable {
                id: scroller
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.bottomMargin: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: !launcher.dragging && !launcher.openFolder
                contentWidth: width
                contentHeight: Math.max(height, stage.rows * stage.cellH + 24)
                visible: !launcher.openFolder || launcher.searching

                Text {
                    anchors.centerIn: parent
                    visible: launcher.itemCount === 0
                    text: "No Results"
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 18
                }

                Item {
                    id: grid
                    width: launcher.columns * stage.cellW
                    height: stage.rows * stage.cellH
                    x: Math.round((scroller.width - width) / 2)
                    y: 8

                    Repeater {
                        model: launcher.results.length

                        Item {
                            id: cell
                            required property int index
                            readonly property var modelData: launcher.results[cell.index]
                            readonly property int globalIndex: cell.index
                            readonly property bool selected: cell.globalIndex === launcher.selectedIndex
                            readonly property bool moving: launcher.dragging && launcher.dragFrom === cell.globalIndex
                            readonly property int col: cell.index % launcher.columns
                            readonly property int row: Math.floor(cell.index / launcher.columns)
                            readonly property int vis: launcher.flowIndexFor(cell.globalIndex)
                            readonly property bool isFolder: cell.modelData && cell.modelData.type === "folder"

                            width: stage.cellW
                            height: stage.cellH
                            x: cell.col * stage.cellW + cell.flowX
                            y: cell.row * stage.cellH + cell.flowY
                            z: cell.moving ? 0 : 1

                            property real flowX: {
                                if (cell.moving || launcher.flowLock)
                                    return 0;
                                return (cell.vis % launcher.columns - cell.col) * stage.cellW;
                            }
                            property real flowY: {
                                if (cell.moving || launcher.flowLock)
                                    return 0;
                                return (Math.floor(cell.vis / launcher.columns) - cell.row) * stage.cellH;
                            }

                            Behavior on flowX {
                                enabled: !launcher.flowLock
                                SpringAnimation {
                                    spring: 4.4
                                    damping: 0.34
                                    mass: 1.0
                                    epsilon: 0.18
                                }
                            }
                            Behavior on flowY {
                                enabled: !launcher.flowLock
                                SpringAnimation {
                                    spring: 4.4
                                    damping: 0.34
                                    mass: 1.0
                                    epsilon: 0.18
                                }
                            }

                            opacity: cell.moving ? 0 : launcher.intro
                            scale: 0.92 + 0.08 * launcher.intro
                            transformOrigin: Item.Center

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 6
                                width: Math.round(Math.min(88, cell.width * 0.58)) + 10
                                height: width
                                radius: 22
                                color: launcher.mergeDrop && launcher.hoverSlot === cell.globalIndex && launcher.dragFrom !== cell.globalIndex ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                            }

                            Item {
                                id: glyph
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                width: icon.width + 24
                                height: parent.height - 8

                                Item {
                                    id: icon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 10
                                    width: Math.round(Math.min(88, cell.width * 0.56))
                                    height: width
                                    scale: iconMouse.containsMouse && !launcher.dragging ? 1.08 : 1
                                    transformOrigin: Item.Center

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 140
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Image {
                                        visible: !cell.isFolder
                                        anchors.fill: parent
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 128
                                        sourceSize.height: 128
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        source: cell.modelData && cell.modelData.entry ? Services.AppsService.iconSource(cell.modelData.entry) : ""
                                    }

                                    Components.FolderGlyph {
                                        visible: cell.isFolder
                                        anchors.fill: parent
                                        apps: cell.modelData && cell.modelData.apps ? cell.modelData.apps : []
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: icon.bottom
                                    anchors.topMargin: 8
                                    text: cell.modelData ? (cell.modelData.name || Services.AppsService.displayName(cell.modelData.entry)) : ""
                                    color: "#FFFFFF"
                                    font.family: Core.Theme.fontFamily
                                    font.pixelSize: 11
                                    font.weight: cell.selected ? Font.DemiBold : Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                                    opacity: cell.moving ? 0 : 1
                                }

                                MouseArea {
                                    id: iconMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: launcher.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool dragged: false

                                    onPressed: function (mouse) {
                                        if (mouse.button !== Qt.LeftButton)
                                            return;
                                        pressX = mouse.x;
                                        pressY = mouse.y;
                                        dragged = false;
                                        launcher.selectedIndex = cell.globalIndex;
                                    }
                                    onPositionChanged: function (mouse) {
                                        if (!(iconMouse.pressed && (mouse.buttons & Qt.LeftButton)))
                                            return;
                                        if (launcher.searching)
                                            return;
                                        if (!dragged && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 8) {
                                            dragged = true;
                                            launcher.dragFrom = cell.globalIndex;
                                            launcher.hoverSlot = cell.globalIndex;
                                        }
                                        if (!dragged)
                                            return;
                                        const layer = launcher.parent;
                                        const p = iconMouse.mapToItem(layer, mouse.x, mouse.y);
                                        launcher.dragX = p.x;
                                        launcher.dragY = p.y;
                                        const dock = launcher.dockTarget;
                                        let overDock = false;
                                        if (dock) {
                                            const d = iconMouse.mapToItem(dock, mouse.x, mouse.y);
                                            overDock = dock.containsApps ? dock.containsApps(d.x, d.y) : (d.x >= -24 && d.x <= dock.width + 24 && d.y >= -28 && d.y <= dock.height + 28);
                                            Services.AppsService.dockDropActive = overDock;
                                            if (overDock)
                                                Services.AppsService.dockHoverSlot = dock.slotAt(d.x, d.y);
                                        }
                                        if (overDock) {
                                            launcher.hoverSlot = launcher.dragFrom;
                                            launcher.mergeDrop = false;
                                            edgeScroll.stop();
                                            edgeScroll.dir = 0;
                                            return;
                                        }
                                        const g = iconMouse.mapToItem(grid, mouse.x, mouse.y);
                                        const s = iconMouse.mapToItem(scroller, mouse.x, mouse.y);
                                        stage.trackEdge(s.y);
                                        const slot = stage.slotAtGrid(g.x, g.y);
                                        if (slot >= 0)
                                            launcher.hoverSlot = slot;
                                        launcher.mergeDrop = slot >= 0 && slot !== launcher.dragFrom && stage.overIcon(g.x, g.y, slot);
                                    }
                                    onReleased: function (mouse) {
                                        if (mouse.button !== Qt.LeftButton) {
                                            dragged = false;
                                            return;
                                        }
                                        edgeScroll.stop();
                                        edgeScroll.dir = 0;
                                        if (dragged && launcher.dragFrom >= 0) {
                                            dragged = false;
                                            launcher.commitDrag();
                                            return;
                                        }
                                        dragged = false;
                                        launcher.selectedIndex = cell.globalIndex;
                                        launcher.accepted();
                                    }
                                    onCanceled: {
                                        dragged = false;
                                        edgeScroll.stop();
                                        edgeScroll.dir = 0;
                                        launcher.resetDrag();
                                    }
                                    onClicked: function (mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            if (cell.modelData && cell.modelData.type !== "folder")
                                                Services.AppsService.toggleDockPin(cell.modelData.id);
                                            mouse.accepted = true;
                                        }
                                    }
                                    onEntered: {
                                        if (!launcher.dragging)
                                            launcher.selectedIndex = cell.globalIndex;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                z: 5
                visible: scroller.contentHeight > scroller.height + 4 && (!launcher.openFolder || launcher.searching)
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.top: scroller.top
                anchors.bottom: scroller.bottom
                width: 3
                radius: 1.5
                color: Qt.rgba(1, 1, 1, 0.10)

                Rectangle {
                    width: parent.width
                    radius: parent.radius
                    color: Qt.rgba(1, 1, 1, 0.42)
                    height: Math.max(20, parent.height * scroller.height / Math.max(1, scroller.contentHeight))
                    y: {
                        const range = Math.max(1, scroller.contentHeight - scroller.height);
                        return (parent.height - height) * Math.max(0, Math.min(1, scroller.contentY / range));
                    }
                }
            }

            Rectangle {
                id: folderLayer
                anchors.fill: parent
                visible: !!(launcher.openFolder && !launcher.searching)
                z: 30
                color: Qt.rgba(0, 0, 0, 0.38)

                readonly property int folderCount: launcher.openFolder ? launcher.openFolder.apps.length : 0
                readonly property int folderCols: Math.min(4, Math.max(1, folderLayer.folderCount))
                readonly property int folderRows: Math.max(1, Math.ceil(folderLayer.folderCount / folderLayer.folderCols))
                readonly property int cellW: 108
                readonly property int cellH: 120

                MouseArea {
                    anchors.fill: parent
                    onClicked: Services.AppsService.closeFolder()
                }

                Rectangle {
                    id: sheet
                    width: Math.min(parent.width - 64, folderLayer.folderCols * folderLayer.cellW + 56)
                    height: Math.min(parent.height - 48, 76 + folderLayer.folderRows * folderLayer.cellH + 20)
                    anchors.centerIn: parent
                    radius: 18
                    color: Qt.rgba(0.12, 0.12, 0.14, 0.82)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.28)
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                    }

                    TextInput {
                        id: folderTitle
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 16
                        height: 28
                        text: launcher.openFolder ? launcher.openFolder.name : ""
                        color: "#FFFFFF"
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        selectByMouse: true
                        onEditingFinished: {
                            if (launcher.openFolder)
                                Services.AppsService.renameFolder(launcher.openFolder.id, folderTitle.text);
                        }
                    }

                    Flickable {
                        id: folderScroll
                        anchors.top: folderTitle.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 10
                        anchors.bottomMargin: 16
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick
                        interactive: !launcher.folderDragging
                        pressDelay: 0
                        contentWidth: width
                        contentHeight: Math.max(height, folderLayer.folderRows * folderLayer.cellH)

                        Item {
                            id: folderGrid
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: folderLayer.folderCols * folderLayer.cellW
                            height: folderLayer.folderRows * folderLayer.cellH

                            Repeater {
                                model: folderLayer.folderCount

                                Item {
                                    id: fapp
                                    required property int index
                                    readonly property var appEntry: launcher.openFolder ? launcher.openFolder.apps[fapp.index] : null
                                    readonly property int col: fapp.index % folderLayer.folderCols
                                    readonly property int row: Math.floor(fapp.index / folderLayer.folderCols)
                                    readonly property int vis: stage.folderFlowIndexFor(fapp.index)
                                    readonly property bool moving: launcher.folderDragging && launcher.folderDragFrom === fapp.index
                                    width: folderLayer.cellW
                                    height: folderLayer.cellH
                                    x: fapp.col * folderLayer.cellW + fapp.flowX
                                    y: fapp.row * folderLayer.cellH + fapp.flowY
                                    z: fapp.moving ? 0 : 1
                                    opacity: fapp.moving ? 0 : 1

                                    property real flowX: {
                                        if (fapp.moving || launcher.flowLock)
                                            return 0;
                                        return (fapp.vis % folderLayer.folderCols - fapp.col) * folderLayer.cellW;
                                    }
                                    property real flowY: {
                                        if (fapp.moving || launcher.flowLock)
                                            return 0;
                                        return (Math.floor(fapp.vis / folderLayer.folderCols) - fapp.row) * folderLayer.cellH;
                                    }

                                    Behavior on flowX {
                                        enabled: !launcher.flowLock
                                        NumberAnimation {
                                            duration: 160
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on flowY {
                                        enabled: !launcher.flowLock
                                        NumberAnimation {
                                            duration: 160
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 6
                                        width: 64
                                        height: 64
                                        source: fapp.appEntry ? Services.AppsService.iconSource(fapp.appEntry) : ""
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 128
                                        sourceSize.height: 128
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.topMargin: 76
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        text: fapp.appEntry ? Services.AppsService.displayName(fapp.appEntry) : ""
                                        color: "#FFFFFF"
                                        font.family: Core.Theme.fontFamily
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    MouseArea {
                                        id: fappMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        acceptedButtons: Qt.LeftButton
                                        cursorShape: launcher.folderDragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                        property real pressX: 0
                                        property real pressY: 0
                                        property bool dragged: false

                                        onPressed: function (mouse) {
                                            pressX = mouse.x;
                                            pressY = mouse.y;
                                            dragged = false;
                                        }
                                        onPositionChanged: function (mouse) {
                                            if (!fappMouse.pressed)
                                                return;
                                            if (!dragged && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 8) {
                                                dragged = true;
                                                launcher.folderDragApp = fapp.appEntry;
                                                launcher.folderDragFrom = fapp.index;
                                                launcher.folderHoverSlot = fapp.index;
                                            }
                                            if (!dragged)
                                                return;
                                            const layer = launcher.parent;
                                            const p = fappMouse.mapToItem(layer, mouse.x, mouse.y);
                                            launcher.dragX = p.x;
                                            launcher.dragY = p.y;
                                            const overDock = stage.trackDock(fappMouse, mouse.x, mouse.y);
                                            if (overDock) {
                                                launcher.folderHoverSlot = launcher.folderDragFrom;
                                                return;
                                            }
                                            launcher.folderHoverSlot = stage.folderSlotAt(fappMouse, mouse.x, mouse.y);
                                        }
                                        onReleased: function (mouse) {
                                            if (dragged && launcher.folderDragging) {
                                                dragged = false;
                                                stage.finishFolderDrag(fappMouse, mouse.x, mouse.y);
                                                return;
                                            }
                                            dragged = false;
                                            launcher.folderDragApp = null;
                                            launcher.folderDragFrom = -1;
                                            launcher.folderHoverSlot = -1;
                                            Services.AppsService.launch(fapp.appEntry);
                                            launcher.dismiss();
                                        }
                                        onCanceled: {
                                            dragged = false;
                                            launcher.folderDragApp = null;
                                            launcher.folderDragFrom = -1;
                                            launcher.folderHoverSlot = -1;
                                            Services.AppsService.clearDockDrop();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
