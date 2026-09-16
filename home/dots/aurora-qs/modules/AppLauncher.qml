import QtQuick
import "../components" as Components
import "../core" as Core
import "../services" as Services

// Classic Launchpad: fullscreen icon pages, search, drag to reorder.
Components.LauncherView {
    id: launcher

    launcherId: "launcher"
    promptIcon: Core.Icons.search
    placeholder: "Search"
    launchpad: true
    vimNavigation: false

    columns: 7
    pageRows: 4
    cardWidth: 680

    property int dragFrom: -1
    property int hoverSlot: -1
    property real dragX: 0
    property real dragY: 0
    property Item dockTarget: null
    readonly property bool dragging: launcher.dragFrom >= 0
    readonly property bool searching: !!(launcher.query && launcher.query.trim().length)

    readonly property var results: {
        if (!launcher.searching)
            return Services.AppsService.launchpadEntries;
        return Services.AppsService.search(launcher.query);
    }
    itemCount: launcher.results.length

    readonly property int pageCount: Math.max(1, Math.ceil(Math.max(0, launcher.itemCount) / launcher.pageSize))
    readonly property int currentPage: Math.max(0, Math.min(launcher.pageCount - 1, Math.floor(launcher.selectedIndex / launcher.pageSize)))

    onAccepted: {
        if (launcher.dragging)
            return;
        const entry = launcher.results[launcher.selectedIndex];
        if (!entry)
            return;
        launcher.dismiss();
        Services.AppsService.launch(entry);
    }

    contentComponent: Component {
        Item {
            id: stage

            ListView {
                id: pages

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: dots.top
                orientation: ListView.Horizontal
                snapMode: ListView.SnapOneItem
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                interactive: false
                model: launcher.pageCount
                currentIndex: launcher.currentPage
                highlightMoveDuration: 220
                highlightMoveVelocity: -1

                delegate: Item {
                    id: page
                    required property int index
                    width: pages.width
                    height: pages.height

                    readonly property var items: {
                        const start = page.index * launcher.pageSize;
                        const all = launcher.results;
                        const out = [];
                        const end = Math.min(all.length, start + launcher.pageSize);
                        for (let i = start; i < end; i++)
                            out.push(all[i]);
                        return out;
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !launcher.dragging
                        property real pressX: 0
                        property bool dragged: false

                        onPressed: function (mouse) {
                            pressX = mouse.x;
                            dragged = false;
                        }
                        onPositionChanged: function (mouse) {
                            if (Math.abs(mouse.x - pressX) > 24)
                                dragged = true;
                        }
                        onReleased: function (mouse) {
                            const dx = mouse.x - pressX;
                            if (dx <= -80) {
                                launcher.move(launcher.pageSize);
                                return;
                            }
                            if (dx >= 80) {
                                launcher.move(-launcher.pageSize);
                                return;
                            }
                            if (!dragged)
                                launcher.dismiss();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: page.items.length === 0
                        text: "No Results"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 18
                    }

                    Grid {
                        id: grid
                        anchors.centerIn: parent
                        columns: launcher.columns
                        z: 1

                        Repeater {
                            model: page.items.length

                            Item {
                                id: cell
                                required property int index
                                readonly property var modelData: page.items[cell.index]
                                readonly property int globalIndex: page.index * launcher.pageSize + cell.index
                                readonly property bool selected: cell.globalIndex === launcher.selectedIndex
                                readonly property bool moving: launcher.dragging && launcher.dragFrom === cell.globalIndex
                                readonly property bool dropTarget: launcher.dragging && launcher.hoverSlot === cell.globalIndex && launcher.dragFrom !== cell.globalIndex
                                readonly property int col: cell.index % launcher.columns
                                readonly property int row: Math.floor(cell.index / launcher.columns)
                                readonly property real nx: cell.col - (launcher.columns - 1) / 2
                                readonly property real ny: cell.row - (launcher.pageRows - 1) / 2
                                readonly property real spread: 1 - launcher.intro

                                width: Math.max(110, Math.min(170, Math.floor((page.width - 160) / launcher.columns)))
                                height: Math.max(120, Math.min(170, Math.floor((page.height - 20) / launcher.pageRows)))

                                opacity: cell.moving ? 0.28 : launcher.intro
                                scale: 0.82 + 0.18 * launcher.intro
                                transformOrigin: Item.Center
                                transform: Translate {
                                    x: cell.nx * 14 * cell.spread
                                    y: cell.ny * 10 * cell.spread
                                }

                                Item {
                                    id: glyph
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 8
                                    width: icon.width + 24
                                    height: parent.height - 8

                                    Image {
                                        id: icon
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: parent.top
                                        anchors.topMargin: 10
                                        width: Math.round(Math.min(88, cell.width * 0.56))
                                        height: width
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 128
                                        sourceSize.height: 128
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        source: Services.AppsService.iconSource(cell.modelData)
                                        scale: iconMouse.containsMouse && !launcher.dragging ? 1.12 : (iconMouse.pressed ? 0.92 : 1)
                                        transformOrigin: Item.Center

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: iconMouse.pressed ? 70 : 140
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: iconRing
                                        anchors.centerIn: icon
                                        width: icon.width + 12
                                        height: icon.height + 12
                                        radius: 16
                                        z: 2
                                        color: "transparent"
                                        border.width: (cell.selected || iconMouse.containsMouse || cell.dropTarget) ? 2 : 0
                                        border.color: Qt.rgba(1, 1, 1, cell.dropTarget ? 0.9 : 0.7)
                                        visible: iconRing.border.width > 0
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: icon.bottom
                                        anchors.topMargin: 8
                                        text: Services.AppsService.displayName(cell.modelData)
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
                                    }

                                    MouseArea {
                                        id: iconMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
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
                                                launcher.hoverSlot = -1;
                                                return;
                                            }
                                            const g = iconMouse.mapToItem(grid, mouse.x, mouse.y);
                                            const hit = grid.childAt(g.x, g.y);
                                            if (hit && hit.globalIndex !== undefined)
                                                launcher.hoverSlot = hit.globalIndex;
                                        }
                                        onReleased: function (mouse) {
                                            if (mouse.button !== Qt.LeftButton) {
                                                dragged = false;
                                                return;
                                            }
                                            if (dragged && launcher.dragFrom >= 0) {
                                                const entry = launcher.results[launcher.dragFrom];
                                                if (Services.AppsService.dockDropActive)
                                                    Services.AppsService.pinDock(entry && entry.id, Services.AppsService.dockHoverSlot);
                                                else if (launcher.hoverSlot >= 0)
                                                    Services.AppsService.moveLaunchpad(launcher.dragFrom, launcher.hoverSlot);
                                                launcher.dragFrom = -1;
                                                launcher.hoverSlot = -1;
                                                dragged = false;
                                                Services.AppsService.clearDockDrop();
                                                return;
                                            }
                                            dragged = false;
                                            launcher.selectedIndex = cell.globalIndex;
                                            launcher.accepted();
                                        }
                                    onClicked: function (mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            Services.AppsService.toggleDockPin(cell.modelData && cell.modelData.id);
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
            }

            Row {
                id: dots
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28
                height: 18
                spacing: 8
                visible: launcher.pageCount > 1
                opacity: launcher.intro

                Repeater {
                    model: launcher.pageCount

                    Rectangle {
                        required property int index
                        width: 7
                        height: 7
                        radius: 4
                        color: "#FFFFFF"
                        opacity: index === launcher.currentPage ? 0.95 : 0.28

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.selectedIndex = Math.min(launcher.itemCount - 1, index * launcher.pageSize)
                        }
                    }
                }
            }
        }
    }
}
