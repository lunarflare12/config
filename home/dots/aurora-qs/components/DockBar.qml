import QtQuick
import Quickshell.Hyprland

import "../core" as Core
import "../services" as Services

// Vertical glass dock on the left edge. Rounded; windows stay square.
Item {
    id: tray

    property real intro: 1
    property bool interactive: true
    property bool fadeWithIntro: true
    readonly property int radius: 22

    readonly property var pinned: Services.AppsService.dockTiles || []
    readonly property int toplevelCount: (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0
    readonly property var runningTiles: {
        const _ = tray.toplevelCount;
        return tray.collectRunning();
    }
    readonly property var tiles: tray.pinned.concat(tray.runningTiles)
    readonly property var openFolder: Services.AppsService.openFolder
    readonly property bool dropping: Services.AppsService.dockDropActive
    readonly property int dropSlot: Services.AppsService.dockHoverSlot

    property int dragFrom: -1
    property int hoverSlot: -1
    property real dragX: 0
    property real dragY: 0
    property bool holding: false
    property bool menuOpen: false
    property int hoverIndex: -1
    property bool trashHover: false
    readonly property bool folderOpen: !!(tray.openFolder && Core.PopupManager.launchpadIntro < 0.01)
    readonly property bool dragging: tray.dragFrom >= 0

    signal launched

    implicitWidth: 74
    implicitHeight: dockBody.height
    width: implicitWidth
    height: implicitHeight
    clip: false

    readonly property Item hitbox: hit

    opacity: tray.fadeWithIntro ? tray.intro : 1
    scale: 0.86 + 0.14 * tray.intro
    transformOrigin: Item.Left

    transform: Translate {
        x: (1 - tray.intro) * -56
    }

    onIntroChanged: {
        if (tray.intro < 0.5)
            tray.menuOpen = false;
    }

    onMenuOpenChanged: Core.PopupManager.contextMenuOpen = tray.menuOpen

    Connections {
        target: Core.PopupManager
        function onContextMenuOpenChanged() {
            if (!Core.PopupManager.contextMenuOpen)
                tray.menuOpen = false;
        }
    }

    property bool flowLock: false

    function resetPointer() {
        tray.dragFrom = -1;
        tray.hoverSlot = -1;
        tray.holding = false;
        tray.hoverIndex = -1;
        tray.trashHover = false;
    }

    function flowIndexFor(i) {
        const from = tray.dragFrom;
        const to = tray.hoverSlot;
        if (!tray.dragging || from < 0 || to < 0 || from === to)
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

    function skipDockClass(cls) {
        const c = String(cls || "").toLowerCase();
        if (!c)
            return true;
        if (c.indexOf("quickshell") >= 0 || c.indexOf("aurora-") >= 0)
            return true;
        if (c.indexOf("steamwebhelper") >= 0 || c.indexOf("crashmailer") >= 0)
            return true;
        if (c.indexOf("xdg-desktop-portal") >= 0)
            return true;
        return false;
    }

    function tileKey(tile) {
        if (!tile)
            return "";
        if (tile.id)
            return String(tile.id).toLowerCase();
        const e = tile.entry || tile;
        return String(e && e.id || "").toLowerCase();
    }

    function classOfTop(t) {
        const ipc = t && t.lastIpcObject ? t.lastIpcObject : {};
        return String(ipc.class || ipc.initialClass || ipc.initial_class || (t && t.class) || "").toLowerCase();
    }

    function toplevelFor(tile) {
        if (!tile)
            return null;
        if (tile.runningWindow)
            return tile.runningWindow;
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        const entry = tile.entry || tile;
        const cls = String(entry && (entry.startupWmClass || entry.startupClass || entry.wmClass) || "").toLowerCase();
        const name = String(tile.name || entry && entry.name || "").toLowerCase();
        const id = String(tile.id || entry && entry.id || "").toLowerCase();
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            const c = tray.classOfTop(t);
            if (tray.skipDockClass(c))
                continue;
            const title = String(t.title || ipc.title || "").toLowerCase();
            if (cls && (c === cls || c.indexOf(cls) >= 0 || cls.indexOf(c) >= 0))
                return t;
            if (id && c.indexOf(id) >= 0)
                return t;
            if (name.length >= 3 && (c.indexOf(name) >= 0 || title.indexOf(name) >= 0))
                return t;
        }
        return null;
    }

    function collectRunning() {
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        const pinned = tray.pinned;
        const seen = ({});
        for (let i = 0; i < pinned.length; i++) {
            const key = tray.tileKey(pinned[i]);
            if (key)
                seen[key] = true;
            const entry = pinned[i] && pinned[i].entry;
            const cls = String(entry && (entry.startupWmClass || entry.startupClass || "") || "").toLowerCase();
            if (cls)
                seen["cls:" + cls] = true;
        }
        const out = [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            const cls = tray.classOfTop(t);
            if (tray.skipDockClass(cls))
                continue;
            const ws = ipc.workspace || {};
            if (String(ws.name || "").indexOf("special") === 0)
                continue;
            const steamId = Services.AppsService.steamIdFromClass(cls);
            const entry = steamId ? Services.AppsService.entryForSteamId(steamId) : Services.AppsService.entryForClass(cls);
            const id = entry && entry.id ? String(entry.id) : cls;
            const key = id.toLowerCase();
            if (seen[key] || seen["cls:" + cls])
                continue;
            seen[key] = true;
            seen["cls:" + cls] = true;
            out.push({
                "type": "app",
                "id": id,
                "name": Services.AppsService.nameForClass(cls, ipc.title || cls),
                "entry": entry,
                "apps": [],
                "runningWindow": t,
                "transient": true
            });
        }
        return out;
    }

    function slotFromRow(x, y) {
        const n = tray.pinned.length;
        if (n === 0)
            return 0;
        const p = tray.mapToItem(iconsRow, x, y);
        const h = 40;
        return Math.max(0, Math.min(n, Math.round(p.y / h)));
    }

    function finishDrag(unpinId, from, to) {
        tray.flowLock = true;
        tray.resetPointer();
        if (unpinId) {
            Qt.callLater(function () {
                Services.AppsService.unpinDock(unpinId);
                tray.flowLock = false;
            });
            return;
        }
        if (from >= 0 && to >= 0)
            Services.AppsService.moveDock(from, to);
        Qt.callLater(function () {
            tray.flowLock = false;
        });
    }

    function containsApps(x, y) {
        const p = tray.mapToItem(iconsRow, x, y);
        return p.x >= -16 && p.x <= iconsRow.width + 16 && p.y >= -8 && p.y <= iconsRow.height + 8;
    }

    function slotAt(x, y) {
        return tray.slotFromRow(x, y);
    }

    Item {
        id: hit
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 74 + (tray.menuOpen || folderMenu.folderIntro > 0.01 ? Math.max(trashMenu.width, folderMenu.width) + 10 : 0)
        height: dockBody.height

        Item {
            id: dockBody
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            height: Math.max(64, dockCol.implicitHeight + 10)

            Glass {
                anchors.fill: parent
                radius: tray.radius
                strength: 1.0
            }

            Rectangle {
                anchors.fill: parent
                radius: tray.radius
                color: "transparent"
                border.width: tray.dropping ? 3 : 2
                border.color: tray.dropping ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.72)
                antialiasing: true
            }

            Column {
                id: dockCol
                anchors.centerIn: parent
                spacing: 0

                Column {
                    id: iconsRow
                    spacing: 0

                    Repeater {
                        model: tray.tiles.length

                        Item {
                            id: slot
                            required property int index
                            readonly property var modelData: tray.tiles[slot.index]
                            width: 56
                            height: 40
                            opacity: tray.dragging && tray.dragFrom === slot.index ? 0 : 1
                            z: tray.dragging && tray.dragFrom === slot.index ? 0 : 1

                            property real flowY: {
                                if (tray.flowLock)
                                    return 0;
                                if (tray.dropping && !tray.dragging)
                                    return slot.index >= Math.max(0, tray.dropSlot) ? slot.height : 0;
                                if (!tray.dragging || slot.index === tray.dragFrom)
                                    return 0;
                                return (tray.flowIndexFor(slot.index) - slot.index) * slot.height;
                            }

                            Behavior on flowY {
                                enabled: !tray.flowLock
                                SpringAnimation {
                                    spring: 4.4
                                    damping: 0.34
                                    mass: 1.0
                                    epsilon: 0.18
                                }
                            }

                            transform: Translate {
                                y: slot.flowY
                            }

                            Image {
                                id: icon
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                width: 38
                                height: 38
                                source: {
                                    if (slot.modelData && slot.modelData.type === "folder")
                                        return "";
                                    const e = slot.modelData && slot.modelData.entry ? slot.modelData.entry : null;
                                    if (e)
                                        return Services.AppsService.iconSource(e);
                                    return Services.AppsService.iconPathForWindow(slot.runningTop);
                                }
                                visible: !(slot.modelData && slot.modelData.type === "folder")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                cache: true
                                sourceSize.width: 128
                                sourceSize.height: 128
                                scale: tray.interactive && !tray.dragging && !tray.holding && !tray.dropping && tray.hoverIndex === slot.index ? 1.38 : 1.0
                                transformOrigin: Item.Left

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 140
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            FolderGlyph {
                                visible: slot.modelData && slot.modelData.type === "folder"
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                width: 38
                                height: 38
                                apps: slot.modelData && slot.modelData.apps ? slot.modelData.apps : []
                                scale: tray.interactive && !tray.dragging && !tray.holding && !tray.dropping && tray.hoverIndex === slot.index ? 1.38 : 1.0
                                transformOrigin: Item.Left

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 140
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                width: 4
                                height: 4
                                radius: 2
                                color: Core.Theme.text
                                opacity: slot.running ? 0.9 : 0
                            }

                            readonly property var runningTop: tray.toplevelFor(slot.modelData)
                            readonly property bool running: !!slot.runningTop

                            MouseArea {
                                id: iconMouse
                                anchors.fill: parent
                                enabled: tray.interactive
                                hoverEnabled: tray.interactive
                                cursorShape: tray.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                property real pressX: 0
                                property real pressY: 0
                                property bool dragged: false

                                onEntered: {
                                    if (!tray.dragging && !tray.holding)
                                        tray.hoverIndex = slot.index;
                                }
                                onExited: {
                                    if (tray.hoverIndex === slot.index)
                                        tray.hoverIndex = -1;
                                }
                                onPressed: function (mouse) {
                                    pressX = mouse.x;
                                    pressY = mouse.y;
                                    dragged = false;
                                    tray.holding = true;
                                    tray.hoverIndex = slot.index;
                                }
                                onPositionChanged: function (mouse) {
                                    if (!iconMouse.pressed)
                                        return;
                                    if (!dragged && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 8) {
                                        dragged = true;
                                        tray.dragFrom = slot.index;
                                        tray.hoverSlot = slot.index;
                                        tray.hoverIndex = -1;
                                    }
                                    if (!dragged)
                                        return;
                                    const p = iconMouse.mapToItem(tray, mouse.x, mouse.y);
                                    tray.dragX = p.x;
                                    tray.dragY = p.y;
                                    const r = iconMouse.mapToItem(iconsRow, mouse.x, mouse.y);
                                    const n = tray.pinned.length;
                                    const idx = Math.max(0, Math.min(n - 1, Math.round(r.y / 40)));
                                    tray.hoverSlot = idx;
                                }
                                onReleased: function (mouse) {
                                    if (dragged && tray.dragFrom >= 0) {
                                        const p = iconMouse.mapToItem(dockBody, mouse.x, mouse.y);
                                        const from = tray.dragFrom;
                                        const to = tray.hoverSlot;
                                        const unpin = p.x < -28 || p.x > dockBody.width + 28;
                                        const id = slot.modelData && slot.modelData.id;
                                        const extra = !!(slot.modelData && slot.modelData.transient);
                                        dragged = false;
                                        if (extra) {
                                            tray.resetPointer();
                                            if (!unpin && id)
                                                Services.AppsService.pinDock(id, to);
                                            return;
                                        }
                                        tray.finishDrag(unpin ? id : "", from, unpin ? -1 : to);
                                        return;
                                    }
                                    dragged = false;
                                    tray.resetPointer();
                                    if (slot.modelData && slot.modelData.type === "folder") {
                                        Services.AppsService.toggleFolder(slot.modelData.id);
                                        return;
                                    }
                                    if (slot.runningTop) {
                                        const here = Core.Session.activeWorkspaceOnMonitor(Core.Session.focusedMonitorName());
                                        Core.Session.bringWindow(slot.runningTop, here);
                                        return;
                                    }
                                    Services.AppsService.launch(slot.modelData);
                                    tray.launched();
                                }
                                onCanceled: {
                                    dragged = false;
                                    tray.resetPointer();
                                }
                            }
                        }
                    }

                    Item {
                        width: 56
                        height: 6
                        visible: tray.dropping && tray.dropSlot >= tray.pinned.length

                        Rectangle {
                            anchors.centerIn: parent
                            width: 36
                            height: 3
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.7)
                        }
                    }
                }

                Item {
                    width: 56
                    height: 10

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 1
                        radius: 1
                        color: Qt.rgba(1, 1, 1, 0.32)
                    }
                }

                Item {
                    id: trashSlot
                    width: 56
                    height: 40

                    Image {
                        id: trashIcon
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        width: 38
                        height: 38
                        source: Services.DesktopService.trashIcon
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                        cache: true
                        sourceSize.width: 128
                        sourceSize.height: 128
                        scale: tray.interactive && !tray.dragging && !tray.holding && tray.trashHover ? 1.38 : 1.0
                        transformOrigin: Item.Left

                        Behavior on scale {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        id: trashMouse
                        anchors.fill: parent
                        enabled: tray.interactive
                        hoverEnabled: tray.interactive
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: tray.trashHover = !tray.dragging && !tray.holding
                        onExited: tray.trashHover = false
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                tray.menuOpen = true;
                                return;
                            }
                            tray.menuOpen = false;
                            Services.DesktopService.openTrash();
                            tray.launched();
                        }
                    }
                }
            }

            Item {
                visible: tray.dragging && tray.dragFrom >= 0 && tray.dragFrom < tray.tiles.length
                z: 20
                width: 52
                height: 52
                x: tray.dragX - width / 2
                y: tray.dragY - height / 2
                readonly property var dragTile: tray.dragging ? tray.tiles[tray.dragFrom] : null

                FolderGlyph {
                    anchors.fill: parent
                    visible: parent.dragTile && parent.dragTile.type === "folder"
                    apps: parent.dragTile && parent.dragTile.apps ? parent.dragTile.apps : []
                }

                Image {
                    anchors.fill: parent
                    visible: parent.dragTile && parent.dragTile.type !== "folder"
                    source: {
                        const e = parent.dragTile;
                        if (!e || e.type === "folder")
                            return "";
                        return Services.AppsService.iconSource(e.entry || e);
                    }
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    cache: true
                }
            }
        }

        Rectangle {
            id: trashMenu
            visible: tray.menuOpen
            z: 40
            width: 188
            height: menuCol.implicitHeight + 10
            anchors.left: dockBody.right
            anchors.leftMargin: 8
            anchors.bottom: dockBody.bottom
            radius: Core.Theme.radiusMenu
            color: "transparent"
            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.borderActive
            antialiasing: true

            Glass {
                anchors.fill: parent
                radius: parent.radius
                strength: 1.0
            }

            Column {
                id: menuCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                spacing: 1

                Repeater {
                    model: [
                        { "label": "Open", "icon": Core.Icons.folder, "action": "open", "enabled": true, "danger": false },
                        { "label": "Empty Trash", "icon": Core.Icons.trash, "action": "empty", "enabled": Services.DesktopService.trashFull, "danger": true }
                    ]

                    Rectangle {
                        id: row
                        required property var modelData
                        width: menuCol.width
                        height: 30
                        radius: Core.Theme.radiusRow
                        color: "transparent"
                        opacity: row.modelData.enabled ? 1 : 0.42

                        Tactile {
                            anchors.fill: parent
                            radius: Core.Theme.radiusRow
                            hovered: rowMouse.containsMouse && row.modelData.enabled
                            pressed: rowMouse.pressed && row.modelData.enabled
                            hoverScale: 1.03
                            pressScale: 0.94
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 9

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                text: row.modelData.icon
                                font.family: Core.Theme.iconFont
                                font.pixelSize: Core.Theme.iconSizeSmall
                                color: row.modelData.danger ? Core.Theme.danger : Core.Theme.foregroundMuted
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: Core.Theme.fontSize
                                color: row.modelData.danger ? Core.Theme.danger : Core.Theme.foreground
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: row.modelData.enabled
                            cursorShape: row.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                const action = row.modelData.action;
                                tray.menuOpen = false;
                                if (action === "open") {
                                    Services.DesktopService.openTrash();
                                    tray.launched();
                                } else if (action === "empty") {
                                    Services.DesktopService.emptyTrash();
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: folderMenu
            visible: folderMenu.folderIntro > 0.01
            z: 40
            width: 228
            height: folderCol.implicitHeight + 14
            anchors.left: dockBody.right
            anchors.leftMargin: 8
            anchors.verticalCenter: dockBody.verticalCenter
            radius: Core.Theme.radiusMenu
            color: "transparent"
            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.borderActive
            antialiasing: true
            opacity: folderMenu.folderIntro
            scale: 0.92 + 0.08 * folderMenu.folderIntro
            transformOrigin: Item.Left
            property var heldFolder: null
            readonly property var folder: tray.openFolder || folderMenu.heldFolder
            readonly property bool folderWanted: tray.folderOpen
            property real folderIntro: folderMenu.folderWanted ? 1 : 0

            onFolderWantedChanged: {
                if (folderMenu.folderWanted && tray.openFolder)
                    folderMenu.heldFolder = tray.openFolder;
            }
            onFolderIntroChanged: {
                if (folderMenu.folderIntro <= 0.01 && !folderMenu.folderWanted)
                    folderMenu.heldFolder = null;
            }

            Behavior on folderIntro {
                NumberAnimation {
                    duration: folderMenu.folderWanted ? 180 : 140
                    easing.type: folderMenu.folderWanted ? Easing.OutCubic : Easing.InCubic
                }
            }

            Glass {
                anchors.fill: parent
                radius: parent.radius
                strength: 1.0
            }

            Column {
                id: folderCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                TextInput {
                    id: folderName
                    width: parent.width
                    height: 22
                    text: folderMenu.folder ? folderMenu.folder.name : ""
                    color: Core.Theme.foreground
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    selectByMouse: true
                    onEditingFinished: {
                        if (folderMenu.folder)
                            Services.AppsService.renameFolder(folderMenu.folder.id, folderName.text);
                    }
                }

                Grid {
                    id: folderGrid
                    width: parent.width
                    columns: 3
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: folderMenu.folder ? folderMenu.folder.apps.length : 0

                        Item {
                            id: fcell
                            required property int index
                            readonly property var modelData: folderMenu.folder ? folderMenu.folder.apps[fcell.index] : null
                            width: 64
                            height: 72

                            Image {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                width: 40
                                height: 40
                                source: fcell.modelData ? Services.AppsService.iconSource(fcell.modelData) : ""
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                cache: true
                                sourceSize.width: 96
                                sourceSize.height: 96
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                text: fcell.modelData ? Services.AppsService.displayName(fcell.modelData) : ""
                                color: Core.Theme.foreground
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Services.AppsService.launch(fcell.modelData);
                                    tray.launched();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
