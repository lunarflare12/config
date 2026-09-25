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
    readonly property var runningTiles: {
        // Depend on clientsTick only — binding Hyprland.toplevels.length races
        // HyprlandIpc::refreshToplevels and segfaults qs.
        const _ = Core.Session.clientsTick + (Core.Session.ipcReady ? 1 : 0);
        return tray.collectRunning();
    }
    readonly property var tiles: tray.pinned.concat(tray.runningTiles)
    readonly property var dockRows: {
        const pins = tray.pinned || [];
        const run = tray.runningTiles || [];
        const rows = [];
        for (let i = 0; i < pins.length; i++)
            rows.push({
                "kind": "app",
                "tile": pins[i],
                "g": i
            });
        if (run.length)
            rows.push({
                "kind": "sep",
                "tile": null,
                "g": -1
            });
        for (let j = 0; j < run.length; j++)
            rows.push({
                "kind": "app",
                "tile": run[j],
                "g": pins.length + j
            });
        return rows;
    }
    readonly property var openFolder: Services.AppsService.openFolder
    readonly property bool dropping: Services.AppsService.dockDropActive
    readonly property int dropSlot: Services.AppsService.dockHoverSlot

    property int dragFrom: -1
    property int hoverSlot: -1
    property real dragX: 0
    property real dragY: 0
    property bool holding: false
    property bool menuOpen: false
    property bool appMenuOpen: false
    property var menuTile: null
    property real menuY: 0
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
            tray.closeMenus();
    }

    onMenuOpenChanged: Core.PopupManager.contextMenuOpen = tray.menuOpen || tray.appMenuOpen
    onAppMenuOpenChanged: Core.PopupManager.contextMenuOpen = tray.menuOpen || tray.appMenuOpen

    function closeMenus() {
        tray.menuOpen = false;
        tray.appMenuOpen = false;
        tray.menuTile = null;
    }

    function openAppMenu(tile, y) {
        if (!tile || tile.type === "folder")
            return;
        tray.menuOpen = false;
        tray.menuTile = tile;
        tray.menuY = y;
        tray.appMenuOpen = true;
    }

    function tilePinned(tile) {
        if (!tile || tile.transient)
            return false;
        const id = String(tile.id || "");
        if (!id)
            return false;
        return (Services.AppsService.dockOrder || []).indexOf(id) >= 0;
    }

    function runTile(tile) {
        if (!tile)
            return;
        const top = tray.toplevelFor(tile);
        if (top) {
            // Jump to the app's workspace — never drag the window onto the desktop.
            Core.Session.focusWindow(top);
            return;
        }
        if (tray.tileIsRunning(tile)) {
            const cls = String(tile.runningClass || (tile.entry && (tile.entry.startupWmClass || tile.entry.startupClass)) || tile.id || "");
            if (cls)
                Core.Session.focusClass(cls);
            return;
        }
        Services.AppsService.launch(tile);
        tray.launched();
    }

    function closeTile(tile) {
        if (!tile)
            return;
        const top = tray.toplevelFor(tile);
        if (top)
            Core.Session.closeWindow(top);
        const needles = Services.AppsService.entryNeedles(tile.entry || tile);
        if (tile.runningClass && needles.indexOf(tile.runningClass) < 0)
            needles.push(tile.runningClass);
        Core.Session.closeClasses(needles);
    }

    Connections {
        target: Core.PopupManager
        function onContextMenuOpenChanged() {
            if (!Core.PopupManager.contextMenuOpen)
                tray.closeMenus();
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
        if (c.indexOf("chrome_status_icon") >= 0)
            return true;
        return false;
    }

    function topIsLive(t) {
        if (!t)
            return false;
        const ipc = t.lastIpcObject || {};
        if (ipc.mapped === false || ipc.hidden === true)
            return false;
        const size = ipc.size || [];
        const w = Number(size[0] || ipc.width || 0);
        const h = Number(size[1] || ipc.height || 0);
        // Zero-size / unknown geometry is treated as dead — stale Hyprland
        // toplevels after docker/XWayland apps quit often look like this.
        if (!(w > 0 && h > 0))
            return false;
        if (w * h < 64)
            return false;
        // Corroborate against hyprctl snapshot — qs Hyprland.toplevels can
        // keep ghost IDEA/Chrome surfaces after the real client is gone.
        const cls = tray.classOfTop(t);
        const addr = String(t.address || ipc.address || "").toLowerCase().replace(/^0x/, "");
        if (!tray.clientAlive(cls, addr))
            return false;
        return true;
    }

    function clientAlive(cls, addr) {
        const _ = Core.Session.clientsTick;
        const clients = Core.Session.openClients || [];
        const c = String(cls || "").toLowerCase();
        const a = String(addr || "").toLowerCase().replace(/^0x/, "");
        if (!clients.length)
            return false;
        for (let i = 0; i < clients.length; i++) {
            const row = clients[i];
            const ra = String(row.address || "").toLowerCase().replace(/^0x/, "");
            if (a && ra && a === ra)
                return true;
            if (c && String(row.class || "") === c)
                return true;
        }
        return false;
    }

    function classAlive(cls) {
        const c = String(cls || "").toLowerCase();
        if (!c)
            return false;
        const _ = Core.Session.clientsTick;
        const open = Core.Session.openClasses || [];
        if (open.indexOf(c) !== -1)
            return true;
        const aliases = Services.AppsService.classAliases(c);
        for (let i = 0; i < aliases.length; i++) {
            if (open.indexOf(aliases[i]) !== -1)
                return true;
        }
        for (let j = 0; j < open.length; j++) {
            const oa = Services.AppsService.classAliases(open[j]);
            if (oa.indexOf(c) !== -1)
                return true;
            for (let k = 0; k < aliases.length; k++) {
                if (oa.indexOf(aliases[k]) !== -1)
                    return true;
            }
        }
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

    function tileIsRunning(tile) {
        const _ = Core.Session.clientsTick;
        if (!tile)
            return false;
        // hyprctl snapshot only — never trust stale Hyprland.toplevels alone.
        const entry = tile.entry || tile;
        if (entry && Services.AppsService.entryIsRunning(entry, Core.Session.openClasses))
            return true;
        const cls = String(tile.runningClass || "").toLowerCase();
        if (cls && tray.classAlive(cls))
            return true;
        return false;
    }

    function toplevelFor(tile) {
        if (!tile)
            return null;
        const _ = Core.Session.clientsTick;
        const entry = tile.entry || tile;
        // Prefer a live hyprctl client match, then map to a Hyprland toplevel.
        const clients = Core.Session.openClients || [];
        let wantClass = "";
        for (let i = 0; i < clients.length; i++) {
            const row = clients[i];
            const c = String(row.class || "");
            if (!c || tray.skipDockClass(c))
                continue;
            if (entry && Services.AppsService.classMatchesEntry(c, entry)) {
                wantClass = c;
                break;
            }
            const id = String(tile.id || entry && entry.id || "").toLowerCase().replace(/\.desktop$/, "");
            const aliases = Services.AppsService.classAliases(id);
            if (id && (c === id || aliases.indexOf(c) !== -1)) {
                wantClass = c;
                break;
            }
        }
        if (!wantClass && tile.runningClass && tray.classAlive(tile.runningClass))
            wantClass = String(tile.runningClass).toLowerCase();
        if (!wantClass)
            return null;
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let j = 0; j < tops.length; j++) {
            const t = tops[j];
            const c = tray.classOfTop(t);
            if (c !== wantClass && Services.AppsService.classAliases(c).indexOf(wantClass) < 0)
                continue;
            if (!tray.topIsLive(t))
                continue;
            return t;
        }
        return null;
    }

    function pinnedCovers(cls, t) {
        const pins = tray.pinned;
        const aliases = Services.AppsService.classAliases(cls);
        const canon = Services.AppsService.canonicalAppId(cls);
        for (let i = 0; i < pins.length; i++) {
            const tile = pins[i];
            if (!tile || tile.type === "folder")
                continue;
            if (t && tray.toplevelFor(tile) === t)
                return true;
            const entry = tile.entry || tile;
            if (entry && Services.AppsService.classMatchesEntry(cls, entry))
                return true;
            const pid = String(Services.AppsService.canonicalAppId(tile.id) || "").toLowerCase();
            const canonLow = String(canon || "").toLowerCase();
            if (pid && (pid === canonLow || aliases.indexOf(pid) !== -1))
                return true;
            const needles = Services.AppsService.entryNeedles(entry);
            for (let n = 0; n < needles.length; n++) {
                if (needles[n] === cls || aliases.indexOf(needles[n]) !== -1)
                    return true;
            }
        }
        return false;
    }

    function collectRunning() {
        const _ = Core.Session.clientsTick;
        const clients = Core.Session.openClients || [];
        const pinned = tray.pinned;
        const seen = ({});
        for (let i = 0; i < pinned.length; i++) {
            const key = Services.AppsService.canonicalAppId(tray.tileKey(pinned[i]));
            if (key)
                seen[key] = true;
            const entry = pinned[i] && (pinned[i].entry || pinned[i]);
            const needles = Services.AppsService.entryNeedles(entry);
            for (let n = 0; n < needles.length; n++)
                seen["cls:" + needles[n]] = true;
            const extra = Services.AppsService.classAliases(key || tray.tileKey(pinned[i]));
            for (let x = 0; x < extra.length; x++)
                seen["cls:" + extra[x]] = true;
        }
        const out = [];
        const pushTile = function (cls, title) {
            if (tray.skipDockClass(cls))
                return;
            if (tray.pinnedCovers(cls, null))
                return;
            const steamId = Services.AppsService.steamIdFromClass(cls);
            const entry = steamId ? Services.AppsService.entryForSteamId(steamId) : Services.AppsService.entryForClass(cls);
            const rawId = entry && entry.id ? String(entry.id) : cls;
            const id = Services.AppsService.canonicalAppId(rawId) || rawId;
            const key = String(id).toLowerCase();
            const aliases = Services.AppsService.classAliases(cls);
            if (seen[key])
                return;
            for (let a = 0; a < aliases.length; a++) {
                if (seen["cls:" + aliases[a]] || seen[aliases[a]])
                    return;
            }
            seen[key] = true;
            seen["cls:" + cls] = true;
            out.push({
                "type": "app",
                "id": id,
                "name": Services.AppsService.nameForClass(cls, title || cls),
                "entry": entry,
                "apps": [],
                "runningWindow": null,
                "runningClass": cls,
                "transient": true
            });
        };
        // hyprctl clients only — Hyprland.toplevels keeps ghosts after IDEA/Chrome quit.
        for (let j = 0; j < clients.length; j++) {
            const row = clients[j];
            const cls = String(row.class || "");
            if (!cls)
                continue;
            pushTile(cls, row.title || cls);
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
        width: 74 + (tray.menuOpen || tray.appMenuOpen || folderMenu.folderIntro > 0.01 ? Math.max(trashMenu.width, appMenu.width, folderMenu.width) + 10 : 0)

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
                        model: tray.dockRows.length

                        Item {
                            id: slot
                            required property int index
                            readonly property var row: tray.dockRows[slot.index] || ({})
                            readonly property var modelData: slot.row.tile
                            readonly property bool isSep: slot.row.kind === "sep"
                            readonly property int gIndex: Number(slot.row.g)
                            width: 56
                            height: slot.isSep ? 16 : 40
                            opacity: tray.dragging && tray.dragFrom === slot.gIndex ? 0 : 1
                            z: tray.dragging && tray.dragFrom === slot.gIndex ? 0 : 1

                            property real flowY: {
                                if (slot.isSep || tray.flowLock)
                                    return 0;
                                if (tray.dropping && !tray.dragging)
                                    return slot.gIndex >= 0 && slot.gIndex >= Math.max(0, tray.dropSlot) ? slot.height : 0;
                                if (!tray.dragging || slot.gIndex === tray.dragFrom)
                                    return 0;
                                return (tray.flowIndexFor(slot.gIndex) - slot.gIndex) * slot.height;
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
                                anchors.leftMargin: 8
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
                                visible: !slot.isSep && !(slot.modelData && slot.modelData.type === "folder")
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                asynchronous: true
                                cache: true
                                sourceSize.width: 128
                                sourceSize.height: 128
                                scale: tray.interactive && !tray.dragging && !tray.holding && !tray.dropping && tray.hoverIndex === slot.gIndex ? 1.38 : 1.0
                                transformOrigin: Item.Left

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 140
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            FolderGlyph {
                                visible: !slot.isSep && slot.modelData && slot.modelData.type === "folder"
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                width: 38
                                height: 38
                                apps: slot.modelData && slot.modelData.apps ? slot.modelData.apps : []
                                scale: tray.interactive && !tray.dragging && !tray.holding && !tray.dropping && tray.hoverIndex === slot.gIndex ? 1.38 : 1.0
                                transformOrigin: Item.Left

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 140
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Rectangle {
                                visible: !slot.isSep
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                width: 4
                                height: 4
                                radius: 2
                                color: Core.Theme.text
                                opacity: slot.running ? 0.9 : 0
                            }

                            Rectangle {
                                visible: slot.isSep
                                anchors.centerIn: parent
                                width: 28
                                height: 1
                                radius: 1
                                color: Qt.rgba(1, 1, 1, 0.34)
                            }

                            readonly property var runningTop: tray.toplevelFor(slot.modelData)
                            readonly property bool running: tray.tileIsRunning(slot.modelData)

                            MouseArea {
                                id: iconMouse
                                anchors.fill: parent
                                enabled: tray.interactive && !slot.isSep
                                hoverEnabled: tray.interactive
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: tray.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                property real pressX: 0
                                property real pressY: 0
                                property bool dragged: false

                                onEntered: {
                                    if (!tray.dragging && !tray.holding)
                                        tray.hoverIndex = slot.gIndex;
                                }
                                onExited: {
                                    if (tray.hoverIndex === slot.gIndex)
                                        tray.hoverIndex = -1;
                                }
                                onPressed: function (mouse) {
                                    if (mouse.button === Qt.RightButton)
                                        return;
                                    pressX = mouse.x;
                                    pressY = mouse.y;
                                    dragged = false;
                                    tray.holding = true;
                                    tray.hoverIndex = slot.gIndex;
                                }
                                onPositionChanged: function (mouse) {
                                    if (!iconMouse.pressed)
                                        return;
                                    if (!dragged && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 8) {
                                        dragged = true;
                                        tray.dragFrom = slot.gIndex;
                                        tray.hoverSlot = slot.gIndex;
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
                                onClicked: function (mouse) {
                                    if (mouse.button !== Qt.RightButton)
                                        return;
                                    tray.resetPointer();
                                    const p = iconMouse.mapToItem(dockBody, 0, slot.height / 2);
                                    tray.openAppMenu(slot.modelData, p.y);
                                }

                                onReleased: function (mouse) {
                                    if (mouse.button === Qt.RightButton)
                                        return;
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
                                    tray.runTile(slot.modelData);
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
                                tray.appMenuOpen = false;
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
            id: appMenu
            visible: tray.appMenuOpen && tray.menuTile
            z: 41
            width: 196
            height: appMenuCol.implicitHeight + 10
            anchors.left: dockBody.right
            anchors.leftMargin: 8
            y: Math.max(8, Math.min(dockBody.height - height - 8, tray.menuY - height / 2))
            radius: Core.Theme.radiusMenu
            color: "transparent"
            border.width: Core.Theme.borderWidth
            border.color: Core.Theme.borderActive
            antialiasing: true

            readonly property bool running: tray.tileIsRunning(tray.menuTile)
            readonly property bool pinned: tray.tilePinned(tray.menuTile)

            Glass {
                anchors.fill: parent
                radius: parent.radius
                strength: 1.0
            }

            Column {
                id: appMenuCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 5
                spacing: 1

                Repeater {
                    model: [
                        {
                            "label": appMenu.running ? "Close" : "Open",
                            "icon": appMenu.running ? Core.Icons.close : Core.Icons.folder,
                            "action": appMenu.running ? "close" : "open",
                            "danger": appMenu.running
                        },
                        {
                            "label": appMenu.pinned ? "Unpin" : "Pin",
                            "icon": appMenu.pinned ? Core.Icons.pinOff : Core.Icons.pin,
                            "action": appMenu.pinned ? "unpin" : "pin",
                            "danger": false
                        }
                    ]

                    Rectangle {
                        id: appRow
                        required property var modelData
                        width: appMenuCol.width
                        height: 30
                        radius: Core.Theme.radiusRow
                        color: "transparent"

                        Tactile {
                            anchors.fill: parent
                            radius: Core.Theme.radiusRow
                            hovered: appRowMouse.containsMouse
                            pressed: appRowMouse.pressed
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
                                text: appRow.modelData.icon
                                font.family: Core.Theme.iconFont
                                font.pixelSize: Core.Theme.iconSizeSmall
                                color: appRow.modelData.danger ? Core.Theme.danger : Core.Theme.foregroundMuted
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: appRow.modelData.label
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: Core.Theme.fontSize
                                color: appRow.modelData.danger ? Core.Theme.danger : Core.Theme.foreground
                            }
                        }

                        MouseArea {
                            id: appRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const tile = tray.menuTile;
                                const action = appRow.modelData.action;
                                tray.closeMenus();
                                if (!tile)
                                    return;
                                if (action === "open")
                                    tray.runTile(tile);
                                else if (action === "close")
                                    tray.closeTile(tile);
                                else if (action === "pin")
                                    Services.AppsService.pinDock(tile.id);
                                else if (action === "unpin")
                                    Services.AppsService.unpinDock(tile.id);
                            }
                        }
                    }
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
                        {
                            "label": "Open",
                            "icon": Core.Icons.folder,
                            "action": "open",
                            "danger": false
                        },
                        {
                            "label": "Empty Trash",
                            "icon": Core.Icons.trash,
                            "action": "empty",
                            "danger": true
                        }
                    ]

                    Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool rowEnabled: row.modelData.action !== "empty" || Services.DesktopService.trashFull
                        width: menuCol.width
                        height: 30
                        radius: Core.Theme.radiusRow
                        color: "transparent"
                        opacity: row.rowEnabled ? 1 : 0.42

                        Tactile {
                            anchors.fill: parent
                            radius: Core.Theme.radiusRow
                            hovered: rowMouse.containsMouse && row.rowEnabled
                            pressed: rowMouse.pressed && row.rowEnabled
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
                            enabled: row.rowEnabled
                            cursorShape: row.rowEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
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
