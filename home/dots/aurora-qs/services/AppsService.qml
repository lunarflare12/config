pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Aurora Apps Service
//
// Application list and ranking for the launcher.
// State: ~/.cache/aurora/launcher-usage.json

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string usagePath: root.home + "/.cache/aurora/launcher-usage.json"
    readonly property string layoutPath: root.home + "/.config/aurora/app-layout.json"
    readonly property string layoutLegacyPath: root.home + "/.cache/aurora/app-layout.json"

    property var usage: ({})
    property var launchpadOrder: []
    property var dockOrder: []
    property bool dockConfigured: false
    property bool layoutReady: false
    property string openFolderId: ""

    readonly property var defaultDockNeedles: [
        "firefox", "zen", "google-chrome", "kitty", "thunar", "nemo",
        "cursor", "code", "obsidian", "idea-ultimate", "idea", "steam",
        "xournal", "telegram", "discord"
    ]

    // Frecency

    property FileView usageFile: FileView {
        path: root.usagePath
        blockLoading: true
        printErrors: false
    }

    property FileView layoutFile: FileView {
        path: root.layoutPath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: root.loadLayout()
    }

    property FileView layoutLegacyFile: FileView {
        path: root.layoutLegacyPath
        blockLoading: true
        printErrors: false
    }

    function loadUsage() {
        const raw = root.usageFile.text()
        if (!raw) {
            root.usage = ({})
            return
        }

        try {
            const parsed = JSON.parse(raw)
            root.usage = (parsed && typeof parsed === "object") ? parsed : ({})
        } catch (e) {
            root.usage = ({})
        }
    }

    function bump(id) {
        if (!id || id.length === 0)
            return

        // Copy, then mutate, then assign.
        const next = ({})
        const keys = Object.keys(root.usage)

        for (let i = 0; i < keys.length; i++)
            next[keys[i]] = root.usage[keys[i]]

        next[id] = (next[id] || 0) + 1
        root.usage = next

        root.usageFile.setText(JSON.stringify(next))
    }

    function loadLayout() {
        let raw = root.layoutFile.text()
        if (!raw)
            raw = root.layoutLegacyFile.text()
        if (!raw) {
            root.launchpadOrder = []
            root.dockOrder = []
            root.dockConfigured = false
            root.layoutReady = true
            return
        }

        try {
            const parsed = JSON.parse(raw)
            root.launchpadOrder = root.normalizeLaunchpad(parsed && parsed.launchpad)
            root.dockOrder = Array.isArray(parsed && parsed.dock) ? parsed.dock.map(String) : []
            root.dockConfigured = parsed && Object.prototype.hasOwnProperty.call(parsed, "dock")
        } catch (e) {
            root.launchpadOrder = []
            root.dockOrder = []
            root.dockConfigured = false
        }
        root.layoutReady = true
    }

    function isFolderTile(item) {
        return !!(item && typeof item === "object" && Array.isArray(item.apps))
    }

    function tileId(item) {
        if (typeof item === "string")
            return item
        if (root.isFolderTile(item) && item.id)
            return String(item.id)
        return ""
    }

    function cloneTile(item) {
        if (typeof item === "string")
            return item
        if (!root.isFolderTile(item))
            return item
        return {
            "id": String(item.id || ""),
            "name": String(item.name || "Folder"),
            "apps": (item.apps || []).map(String)
        }
    }

    function normalizeLaunchpad(raw) {
        const src = Array.isArray(raw) ? raw : []
        const out = []
        const seen = ({})
        for (let i = 0; i < src.length; i++) {
            const item = src[i]
            if (typeof item === "string") {
                const id = String(item)
                if (!id || seen["app:" + id])
                    continue
                seen["app:" + id] = true
                out.push(id)
                continue
            }
            if (!root.isFolderTile(item))
                continue
            const fid = String(item.id || "")
            if (!fid || seen["folder:" + fid])
                continue
            const apps = []
            const appSeen = ({})
            const list = item.apps || []
            for (let a = 0; a < list.length; a++) {
                const id = String(list[a] || "")
                if (!id || appSeen[id] || seen["app:" + id])
                    continue
                appSeen[id] = true
                seen["app:" + id] = true
                apps.push(id)
            }
            if (apps.length === 1) {
                out.push(apps[0])
                continue
            }
            if (apps.length === 0)
                continue
            seen["folder:" + fid] = true
            out.push({
                "id": fid,
                "name": String(item.name || "Folder"),
                "apps": apps
            })
        }
        return out
    }

    function serializeLaunchpad() {
        const out = []
        const src = root.launchpadOrder || []
        for (let i = 0; i < src.length; i++) {
            const item = src[i]
            if (typeof item === "string")
                out.push(item)
            else if (root.isFolderTile(item))
                out.push({
                    "id": String(item.id),
                    "name": String(item.name || "Folder"),
                    "apps": (item.apps || []).map(String)
                })
        }
        return out
    }

    function newFolderId() {
        return "folder-" + Date.now() + "-" + Math.floor(Math.random() * 100000)
    }

    function findFolder(id) {
        const needle = String(id || "")
        const src = root.launchpadOrder || []
        for (let i = 0; i < src.length; i++) {
            if (root.isFolderTile(src[i]) && String(src[i].id) === needle)
                return src[i]
        }
        return null
    }

    function saveLayout() {
        root.dockConfigured = true
        root.layoutFile.setText(JSON.stringify({
            "launchpad": root.serializeLaunchpad(),
            "dock": root.dockOrder
        }))
    }

    function sameIds(a, b) {
        if (!a || !b || a.length !== b.length)
            return false
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false
        }
        return true
    }

    function resolveStoredId(id) {
        const needle = String(id || "")
        if (!needle)
            return ""
        const lower = needle.toLowerCase().replace(/\.desktop$/, "")
        const compact = lower.replace(/[^a-z0-9]/g, "")
        const list = root.entries
        for (let i = 0; i < list.length; i++) {
            const e = list[i]
            const eid = String(e && e.id || "")
            if (!eid)
                continue
            const el = eid.toLowerCase().replace(/\.desktop$/, "")
            if (el === lower)
                return eid
        }
        if (compact.length >= 3) {
            for (let i = 0; i < list.length; i++) {
                const e = list[i]
                const eid = String(e && e.id || "")
                if (!eid)
                    continue
                const ec = eid.toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "")
                if (ec === compact || (compact.length >= 5 && (ec.indexOf(compact) !== -1 || compact.indexOf(ec) !== -1)))
                    return eid
            }
        }
        for (let i = 0; i < list.length; i++) {
            const e = list[i]
            const eid = String(e && e.id || "")
            if (!eid)
                continue
            if (root.haystack(e).indexOf(lower) !== -1)
                return eid
        }
        return ""
    }

    function defaultDockIds(entries) {
        const ids = []
        const seen = {}
        const list = entries || root.entries
        for (let n = 0; n < root.defaultDockNeedles.length; n++) {
            const needle = root.defaultDockNeedles[n]
            for (let i = 0; i < list.length; i++) {
                const e = list[i]
                const id = e && e.id ? String(e.id) : ""
                if (!id || seen[id])
                    continue
                const hay = [
                    id,
                    String(e.name || ""),
                    String(e.execString || e.exec || ""),
                    String(e.startupClass || "")
                ].join(" ").toLowerCase()
                if (hay.indexOf(needle) === -1)
                    continue
                seen[id] = true
                ids.push(id)
                break
            }
        }
        return ids
    }

    function syncLayout() {
        const list = root.entries
        if (!list.length)
            return
        if (!root.layoutReady)
            root.loadLayout()

        const have = ({})
        for (let i = 0; i < list.length; i++) {
            const id = list[i] && list[i].id ? String(list[i].id) : ""
            if (id)
                have[id] = true
        }

        const lp = []
        const seenLp = {}
        const prevLp = root.launchpadOrder
        for (let i = 0; i < prevLp.length; i++) {
            const item = root.cloneTile(prevLp[i])
            if (typeof item === "string") {
                const id = item
                if (!id || !have[id] || seenLp["app:" + id])
                    continue
                seenLp["app:" + id] = true
                lp.push(id)
                continue
            }
            if (!root.isFolderTile(item))
                continue
            const apps = []
            for (let a = 0; a < item.apps.length; a++) {
                const id = String(item.apps[a] || "")
                if (!id || !have[id] || seenLp["app:" + id])
                    continue
                seenLp["app:" + id] = true
                apps.push(id)
            }
            if (apps.length === 1) {
                lp.push(apps[0])
                continue
            }
            if (apps.length === 0)
                continue
            item.apps = apps
            seenLp["folder:" + item.id] = true
            lp.push(item)
        }
        for (let i = 0; i < list.length; i++) {
            const id = list[i] && list[i].id ? String(list[i].id) : ""
            if (!id || seenLp["app:" + id])
                continue
            seenLp["app:" + id] = true
            lp.push(id)
        }

        const dock = []
        const seenDock = {}
        const prevDock = root.dockOrder || []
        for (let i = 0; i < prevDock.length; i++) {
            const raw = String(prevDock[i] || "")
            if (!raw || seenDock[raw])
                continue
            if (raw.indexOf("folder-") === 0) {
                seenDock[raw] = true
                dock.push(raw)
                continue
            }
            const id = root.resolveStoredId(raw) || raw
            if (!id || seenDock[id])
                continue
            seenDock[id] = true
            seenDock[raw] = true
            dock.push(seenLp["app:" + id] ? id : raw)
        }

        let dockChanged = false
        if (dock.length === 0 && !root.dockConfigured) {
            const defaults = root.defaultDockIds(list)
            if (defaults.length) {
                root.dockOrder = defaults
                root.dockConfigured = true
                dockChanged = true
            }
        } else if (dock.length < prevDock.length && prevDock.length > 2) {
            // Desktop entries arrive in waves. A short catalog used to persist
            // an empty dock and wipe pins across restarts.
        } else if (!root.sameIds(root.dockOrder, dock)) {
            root.dockOrder = dock
            dockChanged = true
        }

        const lpChanged = !root.sameLaunchpad(root.launchpadOrder, lp)
        if (lpChanged)
            root.launchpadOrder = lp
        if (lpChanged || dockChanged)
            root.saveLayout()
    }

    function sameLaunchpad(a, b) {
        if (!a || !b || a.length !== b.length)
            return false
        for (let i = 0; i < a.length; i++) {
            const left = a[i]
            const right = b[i]
            if (typeof left === "string" || typeof right === "string") {
                if (left !== right)
                    return false
                continue
            }
            if (!root.isFolderTile(left) || !root.isFolderTile(right))
                return false
            if (String(left.id) !== String(right.id) || String(left.name) !== String(right.name))
                return false
            if (!root.sameIds(left.apps || [], right.apps || []))
                return false
        }
        return true
    }

    function byIdMap() {
        const map = ({})
        const list = root.entries
        for (let i = 0; i < list.length; i++) {
            const e = list[i]
            if (e && e.id)
                map[String(e.id)] = e
        }
        return map
    }

    readonly property var launchpadTiles: {
        const order = root.launchpadOrder
        const _n = order ? order.length : 0
        const _e = root.entries.length
        const map = root.byIdMap()
        const out = []
        for (let i = 0; i < _n; i++) {
            const item = order[i]
            if (typeof item === "string") {
                const id = root.resolveStoredId(item) || item
                const e = map[id] || map[item]
                if (e)
                    out.push({ "type": "app", "id": String(e.id || id), "name": root.displayName(e), "entry": e, "apps": [] })
                continue
            }
            if (!root.isFolderTile(item))
                continue
            const apps = []
            const ids = item.apps || []
            for (let a = 0; a < ids.length; a++) {
                const raw = String(ids[a] || "")
                const id = root.resolveStoredId(raw) || raw
                const e = map[id] || map[raw]
                if (e)
                    apps.push(e)
            }
            if (apps.length < 2)
                continue
            out.push({
                "type": "folder",
                "id": String(item.id),
                "name": String(item.name || "Folder"),
                "entry": null,
                "apps": apps
            })
        }
        return out
    }

    readonly property var launchpadEntries: {
        const tiles = root.launchpadTiles
        const out = []
        for (let i = 0; i < tiles.length; i++) {
            if (tiles[i].type === "app" && tiles[i].entry)
                out.push(tiles[i].entry)
        }
        return out
    }

    readonly property var dockTiles: {
        const order = root.dockOrder
        const _n = order ? order.length : 0
        const _e = root.entries.length
        const map = root.byIdMap()
        const folders = ({})
        const lp = root.launchpadTiles
        for (let i = 0; i < lp.length; i++) {
            if (lp[i].type === "folder")
                folders[lp[i].id] = lp[i]
        }
        const out = []
        for (let i = 0; i < _n; i++) {
            const raw = String(order[i] || "")
            if (!raw)
                continue
            if (folders[raw]) {
                out.push(folders[raw])
                continue
            }
            const id = root.resolveStoredId(raw) || raw
            if (folders[id]) {
                out.push(folders[id])
                continue
            }
            const e = map[id] || map[raw]
            if (e)
                out.push({ "type": "app", "id": String(e.id || id), "name": root.displayName(e), "entry": e, "apps": [] })
        }
        return out
    }

    readonly property var dockEntries: {
        const tiles = root.dockTiles
        const out = []
        for (let i = 0; i < tiles.length; i++) {
            if (tiles[i].type === "app" && tiles[i].entry)
                out.push(tiles[i].entry)
        }
        return out
    }

    readonly property var openFolder: {
        const id = String(root.openFolderId || "")
        if (!id)
            return null
        const tiles = root.launchpadTiles
        for (let i = 0; i < tiles.length; i++) {
            if (tiles[i].type === "folder" && tiles[i].id === id)
                return tiles[i]
        }
        return null
    }

    function moveIds(ids, from, to) {
        const next = ids.slice()
        if (from < 0 || from >= next.length)
            return ids
        const dest = Math.max(0, Math.min(next.length - 1, to))
        if (from === dest)
            return ids
        const item = next.splice(from, 1)[0]
        next.splice(dest, 0, item)
        return next
    }

    function moveVisibleIds(visible, from, to, stored) {
        const ids = []
        for (let i = 0; i < visible.length; i++) {
            const id = visible[i] && visible[i].id ? String(visible[i].id) : ""
            if (id)
                ids.push(id)
        }
        const nextVisible = root.moveIds(ids, from, to)
        const seen = ({})
        for (let i = 0; i < nextVisible.length; i++)
            seen[String(nextVisible[i])] = true
        const rest = []
        const prev = stored || []
        for (let i = 0; i < prev.length; i++) {
            const id = String(prev[i] || "")
            if (id && !seen[id])
                rest.push(id)
        }
        return nextVisible.concat(rest)
    }

    function orderIndexOfTile(tile) {
        if (!tile)
            return -1
        const src = root.launchpadOrder || []
        const id = String(tile.id || "")
        if (!id)
            return -1
        for (let i = 0; i < src.length; i++) {
            if (tile.type === "folder") {
                if (root.isFolderTile(src[i]) && String(src[i].id) === id)
                    return i
            } else if (typeof src[i] === "string" && (String(src[i]) === id || root.resolveStoredId(src[i]) === id)) {
                return i
            }
        }
        return -1
    }

    function moveLaunchpad(from, to) {
        const tiles = root.launchpadTiles
        if (from < 0 || to < 0 || from >= tiles.length || to >= tiles.length)
            return
        const fromOrder = root.orderIndexOfTile(tiles[from])
        const toOrder = root.orderIndexOfTile(tiles[to])
        if (fromOrder < 0 || toOrder < 0 || fromOrder === toOrder)
            return
        const next = root.launchpadOrder.slice()
        const dest = Math.max(0, Math.min(next.length - 1, toOrder))
        const item = next.splice(fromOrder, 1)[0]
        next.splice(Math.max(0, Math.min(next.length, dest)), 0, item)
        if (root.sameLaunchpad(next, root.launchpadOrder))
            return
        root.launchpadOrder = next
        root.saveLayout()
    }

    function mergeLaunchpad(from, to) {
        const tiles = root.launchpadTiles
        if (from < 0 || to < 0 || from === to)
            return
        if (from >= tiles.length || to >= tiles.length)
            return
        const movingTile = tiles[from]
        const targetTile = tiles[to]
        const fromOrder = root.orderIndexOfTile(movingTile)
        const toOrder = root.orderIndexOfTile(targetTile)
        if (fromOrder < 0 || toOrder < 0)
            return
        const src = root.launchpadOrder.slice()
        const moving = root.cloneTile(src[fromOrder])
        const target = root.cloneTile(src[toOrder])
        if (root.isFolderTile(moving)) {
            root.moveLaunchpad(from, to)
            return
        }
        const appId = root.tileId(moving) || String(movingTile.id || "")
        if (!appId)
            return
        if (root.isFolderTile(target)) {
            const apps = (target.apps || []).map(String)
            if (apps.indexOf(appId) < 0)
                apps.push(appId)
            target.apps = apps
            src[toOrder] = target
            src.splice(fromOrder, 1)
            root.launchpadOrder = root.normalizeLaunchpad(src)
            root.openFolderId = String(target.id || targetTile.id || "")
            root.saveLayout()
            return
        }
        const otherId = root.tileId(target) || String(targetTile.id || "")
        if (!otherId || otherId === appId)
            return
        const folder = {
            "id": root.newFolderId(),
            "name": "Folder",
            "apps": [otherId, appId]
        }
        const insertAt = fromOrder < toOrder ? toOrder - 1 : toOrder
        const next = []
        for (let i = 0; i < src.length; i++) {
            if (i === fromOrder || i === toOrder)
                continue
            next.push(src[i])
        }
        next.splice(Math.max(0, Math.min(next.length, insertAt)), 0, folder)
        root.launchpadOrder = root.normalizeLaunchpad(next)
        root.openFolderId = folder.id
        root.saveLayout()
    }

    function renameFolder(id, name) {
        const needle = String(id || "")
        const label = String(name || "").trim() || "Folder"
        const src = root.launchpadOrder.slice()
        let changed = false
        for (let i = 0; i < src.length; i++) {
            if (root.isFolderTile(src[i]) && String(src[i].id) === needle) {
                const tile = root.cloneTile(src[i])
                tile.name = label
                src[i] = tile
                changed = true
                break
            }
        }
        if (!changed)
            return
        root.launchpadOrder = src
        root.saveLayout()
    }

    function moveInFolder(folderId, from, to) {
        const fid = String(folderId || "")
        const src = root.launchpadOrder.slice()
        for (let i = 0; i < src.length; i++) {
            if (!root.isFolderTile(src[i]) || String(src[i].id) !== fid)
                continue
            const tile = root.cloneTile(src[i])
            const apps = (tile.apps || []).map(String)
            const next = root.moveIds(apps, from, to)
            if (root.sameIds(next, apps))
                return
            tile.apps = next
            src[i] = tile
            root.launchpadOrder = src
            root.saveLayout()
            return
        }
    }

    function removeFromFolder(folderId, appId) {
        const fid = String(folderId || "")
        const aid = String(appId || "")
        const src = root.launchpadOrder.slice()
        let folderIndex = -1
        for (let i = 0; i < src.length; i++) {
            if (!root.isFolderTile(src[i]) || String(src[i].id) !== fid)
                continue
            folderIndex = i
            const tile = root.cloneTile(src[i])
            tile.apps = (tile.apps || []).filter(function (id) {
                return String(id) !== aid
            })
            src[i] = tile
            break
        }
        if (folderIndex < 0)
            return
        src.splice(folderIndex + 1, 0, aid)
        root.launchpadOrder = root.normalizeLaunchpad(src)
        if (!root.findFolder(fid))
            root.openFolderId = ""
        root.saveLayout()
    }

    function closeFolder() {
        root.openFolderId = ""
    }

    function toggleFolder(id) {
        const needle = String(id || "")
        root.openFolderId = root.openFolderId === needle ? "" : needle
    }

    function moveDock(from, to) {
        const next = root.moveVisibleIds(root.dockTiles, from, to, root.dockOrder)
        if (root.sameIds(next, root.dockOrder))
            return
        root.dockOrder = next
        root.saveLayout()
    }

    function isDockPinned(id) {
        const needle = String(id || "")
        if (!needle)
            return false
        const dock = root.dockOrder
        for (let i = 0; i < dock.length; i++) {
            if (String(dock[i]) === needle)
                return true
        }
        return false
    }

    function toggleDockPin(id) {
        const needle = String(id || "")
        if (!needle)
            return
        const dock = root.dockOrder.slice()
        const idx = dock.indexOf(needle)
        if (idx >= 0)
            dock.splice(idx, 1)
        else
            dock.push(needle)
        root.dockOrder = dock
        root.saveLayout()
    }

    property bool dockDropActive: false
    property int dockHoverSlot: -1
    property bool launchpadDragging: false

    function clearDockDrop() {
        root.dockDropActive = false
        root.dockHoverSlot = -1
        root.launchpadDragging = false
    }

    function pinDock(id, at) {
        const needle = String(id || "")
        if (!needle)
            return
        const dock = root.dockOrder.filter(function (item) {
            return String(item) !== needle
        })
        let dest = dock.length
        if (typeof at === "number" && at >= 0)
            dest = Math.max(0, Math.min(dock.length, at))
        dock.splice(dest, 0, needle)
        if (root.sameIds(dock, root.dockOrder))
            return
        root.dockOrder = dock
        root.saveLayout()
    }

    function unpinDock(id) {
        const needle = String(id || "")
        if (!needle)
            return
        const dock = root.dockOrder.filter(function (item) {
            return String(item) !== needle
        })
        if (root.sameIds(dock, root.dockOrder))
            return
        root.dockOrder = dock
        root.saveLayout()
    }

    // Entries

    property var entries: []

    readonly property var rawApps: DesktopEntries.applications.values

    onRawAppsChanged: root.rebuildEntries()

    readonly property string finderIcon: "file://" + Quickshell.shellDir + "/assets/finder-icon.png"
    readonly property string keymappIcon: "file://" + Quickshell.shellDir + "/assets/keymapp.png"
    readonly property string sattyIcon: "file://" + Quickshell.shellDir + "/assets/satty.png"
    readonly property string kittyIcon: "file://" + Quickshell.shellDir + "/assets/kitty.png"
    readonly property string amneziaIcon: "file://" + Quickshell.shellDir + "/assets/amnezia.png"

    function haystack(entry) {
        return [
            entry.id,
            entry.name,
            entry.execString,
            entry.exec,
            entry.startupClass,
            entry.startupWmClass,
            entry.icon
        ].join(" ").toLowerCase()
    }

    function isGuiApp(entry) {
        if (entry.runInTerminal === true || entry.terminal === true)
            return false

        const cats = entry.categories
        if (cats) {
            for (let i = 0; i < cats.length; i++) {
                const cat = String(cats[i]).toLowerCase()
                if (cat === "consoleonly")
                    return false
            }
        }

        return true
    }

    function isJunk(entry) {
        const text = root.haystack(entry)
        const deny = [
            "kvantum",
            "qt5ct",
            "qt6ct",
            "qv4l2",
            "qvidcap",
            "nm-connection",
            "uuctl",
            "pavucontrol",
            "zathura"
        ]

        for (let i = 0; i < deny.length; i++) {
            if (text.indexOf(deny[i]) !== -1)
                return true
        }

        return false
    }

    function isFileManager(entry) {
        const text = root.haystack(entry)
        if (text.indexOf("thunar") !== -1)
            return true

        const cats = entry.categories
        if (cats) {
            for (let i = 0; i < cats.length; i++) {
                if (String(cats[i]).toLowerCase() === "filemanager")
                    return true
            }
        }

        return false
    }

    function isMainFileManager(entry) {
        const id = String(entry.id || "").toLowerCase()
        return id === "thunar" || id === "org.xfce.thunar" || id === "finder"
    }

    function isKeymapp(entry) {
        const text = root.haystack(entry)
        return text.indexOf("keymapp") !== -1
    }

    function isSatty(entry) {
        return root.haystack(entry).indexOf("satty") !== -1
    }

    function isKitty(entry) {
        if (!entry)
            return false
        const blob = root.haystack(entry)
        const icon = String(entry.icon || "").toLowerCase()
        return blob.indexOf("kitty") !== -1 || icon.indexOf("kitty") !== -1
    }

    function isAmnezia(entry) {
        if (!entry)
            return false
        return root.haystack(entry).indexOf("amnezia") !== -1
    }

    function isSpotify(entry) {
        if (!entry)
            return false
        const id = String(entry.id || "").toLowerCase()
        if (id === "spotify" || id.indexOf("spotify") !== -1)
            return true
        return root.haystack(entry).indexOf("spotify") !== -1
    }

    function resolveIcon(icon, fallback) {
        const name = String(icon || "")
        const fb = fallback || "application-x-executable"
        if (!name)
            return Quickshell.iconPath(fb)
        if (name.indexOf("://") >= 0)
            return name
        if (name.charAt(0) === "/")
            return "file://" + name
        return Quickshell.iconPath(name, fb)
    }

    function iconSource(entry) {
        if (!entry)
            return Quickshell.iconPath("application-x-executable")
        if (root.isMainFileManager(entry))
            return root.finderIcon
        if (root.isKeymapp(entry))
            return root.keymappIcon
        if (root.isSatty(entry))
            return root.sattyIcon
        if (root.isKitty(entry))
            return root.kittyIcon
        if (root.isAmnezia(entry))
            return root.amneziaIcon
        return root.resolveIcon(entry.icon, "application-x-executable")
    }

    function displayName(entry) {
        if (root.isMainFileManager(entry))
            return "Finder"
        return entry && entry.name ? entry.name : "App"
    }

    function steamAppId(entry) {
        const exec = String(entry && (entry.execString || entry.exec) || "").toLowerCase()
        const match = exec.match(/rungameid\/(\d+)/)
        return match ? match[1] : ""
    }

    function rebuildEntries() {
        const source = DesktopEntries.applications.values
        if (!source || source.length === 0)
            return

        const out = []
        const seenSteam = {}
        const seenName = {}

        for (let i = 0; i < source.length; i++) {
            const entry = source[i]
            if (!entry)
                continue

            if (entry.noDisplay === true)
                continue

            if (!entry.name || entry.name.length === 0)
                continue

            if (!root.isGuiApp(entry))
                continue

            if (root.isJunk(entry))
                continue

            if (root.isFileManager(entry) && !root.isMainFileManager(entry))
                continue

            const steamId = root.steamAppId(entry)
            if (steamId) {
                if (seenSteam[steamId])
                    continue
                seenSteam[steamId] = true
            } else {
                const nameKey = String(entry.name).toLowerCase().replace(/®/g, "").trim()
                if (seenName[nameKey])
                    continue
                seenName[nameKey] = true
            }

            out.push(entry)
        }

        out.sort(function (a, b) {
            const an = a.name.toLowerCase()
            const bn = b.name.toLowerCase()

            if (an < bn)
                return -1

            if (an > bn)
                return 1

            return 0
        })

        if (root.entries.length > 8 && out.length < Math.ceil(root.entries.length * 0.5))
            return

        const cur = root.entries
        if (cur.length === out.length) {
            let same = true
            for (let i = 0; i < out.length; i++) {
                if (cur[i].id !== out[i].id) {
                    same = false
                    break
                }
            }
            if (same) {
                if (!root.launchpadOrder.length || !root.dockOrder.length)
                    root.syncLayout()
                return
            }
        }

        root.entries = out
        root.syncLayout()
    }

    readonly property int count: root.entries.length

    // Matching

    function subsequence(haystack, needle) {
        let h = 0

        for (let n = 0; n < needle.length; n++) {
            let found = false

            while (h < haystack.length) {
                if (haystack.charAt(h) === needle.charAt(n)) {
                    found = true
                    h++
                    break
                }
                h++
            }

            if (!found)
                return false
        }

        return true
    }

    // Tiers, strongest first.
    function score(entry, q) {
        const name = entry.name ? entry.name.toLowerCase() : ""

        if (name.indexOf(q) === 0)
            return 400

        const words = name.split(/[\s\-_.]+/)
        for (let i = 0; i < words.length; i++) {
            if (words[i].indexOf(q) === 0)
                return 300
        }

        if (name.indexOf(q) !== -1)
            return 200

        const generic = entry.genericName ? entry.genericName.toLowerCase() : ""
        if (generic.length > 0 && generic.indexOf(q) !== -1)
            return 140

        const comment = entry.comment ? entry.comment.toLowerCase() : ""
        if (comment.length > 0 && comment.indexOf(q) !== -1)
            return 100

        const keywords = entry.keywords
        if (keywords) {
            for (let k = 0; k < keywords.length; k++) {
                if (String(keywords[k]).toLowerCase().indexOf(q) !== -1)
                    return 100
            }
        }

        if (root.subsequence(name, q))
            return 60

        return -1
    }

    function search(query) {
        const all = root.entries

        if (!query || query.trim().length === 0) {
            const ranked = all.slice()
            ranked.sort(function (a, b) {
                const ua = root.usage[a.id] || 0
                const ub = root.usage[b.id] || 0
                if (ub !== ua)
                    return ub - ua
                const an = String(a.name || "").toLowerCase()
                const bn = String(b.name || "").toLowerCase()
                if (an < bn)
                    return -1
                if (an > bn)
                    return 1
                return 0
            })
            return ranked
        }

        const q = query.trim().toLowerCase()
        const scored = []

        for (let i = 0; i < all.length; i++) {
            const entry = all[i]
            let s = root.score(entry, q)

            if (s < 0)
                continue

            // Frecency is a tie-breaker, capped so a heavily used app can never leapfrog a genuine prefix match.
            const hits = root.usage[entry.id] || 0
            s += Math.min(50, hits * 6)

            scored.push({ "entry": entry, "score": s, "index": i })
        }

        scored.sort(function (a, b) {
            if (b.score !== a.score)
                return b.score - a.score

            return a.index - b.index
        })

        const out = []
        for (let j = 0; j < scored.length; j++)
            out.push(scored[j].entry)

        return out
    }

    // Actions

    property var pendingLaunch: null
    property bool launchConsumed: false
    signal spawnStarting()

    function splashKind(app) {
        const text = root.haystack(app);
        if (text.indexOf("firefox") !== -1 || text.indexOf("chrome") !== -1 || text.indexOf("chromium") !== -1 || text.indexOf("zen") !== -1 || text.indexOf("brave") !== -1)
            return "browser";
        return "app";
    }

    function skipSplash(app) {
        const text = root.haystack(app);
        if (text.indexOf("steam_app") !== -1 || text.indexOf("rungameid") !== -1)
            return true;
        if (text.indexOf("gamescope") !== -1)
            return true;
        if (text.indexOf("satty") !== -1)
            return true;
        return false;
    }

    function launch(entry) {
        if (!entry)
            return;
        if (entry.type === "folder") {
            root.toggleFolder(entry.id);
            return;
        }
        let app = entry.entry || entry;
        if (app && app.type === "app" && app.entry)
            app = app.entry;
        if (!app)
            return;
        const id = String(app.id || entry.id || "");
        if (id)
            root.bump(id);
        root.closeFolder();
        root.pendingLaunch = app;
        root.launchConsumed = false;
        root.spawnStarting();
        if (root.launchConsumed) {
            root.pendingLaunch = null;
            return;
        }
        if (root.isSpotify(app) || root.isSpotify(entry)) {
            Quickshell.execDetached([root.home + "/.config/scripts/spotify"]);
            root.pendingLaunch = null;
            return;
        }
        if (app.execute) {
            app.execute();
            root.pendingLaunch = null;
            return;
        }
        const cmd = app.command;
        if (cmd && cmd.length) {
            Quickshell.execDetached(cmd);
            root.pendingLaunch = null;
            return;
        }
        const line = String(app.execString || app.exec || "");
        if (line)
            Quickshell.execDetached(["sh", "-c", "exec " + line]);
        root.pendingLaunch = null;
    }

    function steamIdFromClass(cls) {
        const m = String(cls || "").match(/steam_app_(\d+)/i);
        return m ? m[1] : "";
    }

    function entryForSteamId(appid) {
        const id = String(appid || "");
        if (!id)
            return null;
        const entries = root.entries;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e && root.steamAppId(e) === id)
                return e;
        }
        return null;
    }

    function entryForTitle(title) {
        const t = String(title || "").toLowerCase().replace(/®/g, "").trim();
        if (t.length < 4)
            return null;
        const entries = root.entries;
        let best = null;
        let bestLen = 0;
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (!e)
                continue;
            const name = String(e.name || "").toLowerCase().replace(/®/g, "").trim();
            if (name.length < 4)
                continue;
            if (name === t)
                return e;
            if (t.indexOf(name) !== -1 || name.indexOf(t) !== -1) {
                const n = Math.min(name.length, t.length);
                if (n > bestLen) {
                    bestLen = n;
                    best = e;
                }
            }
        }
        return bestLen >= 4 ? best : null;
    }

    function entryForClass(cls) {
        const needle = String(cls || "").toLowerCase().trim();
        if (!needle)
            return null;
        if (needle.indexOf("gamescope") !== -1)
            return null;

        const entries = root.entries;
        let best = null;
        let bestScore = 0;

        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (!e)
                continue;
            const id = String(e.id || "").toLowerCase();
            const start = String(e.startupWmClass || e.startupClass || e.wmClass || "").toLowerCase();
            const icon = String(e.icon || "").toLowerCase();
            const name = String(e.name || "").toLowerCase().replace(/\s+/g, "");
            const exec = String(e.execString || e.exec || "").toLowerCase();
            let score = 0;
            if (start && (start === needle || needle === start))
                score = 100;
            else if (id && (id === needle || id === needle.replace(/-/g, ".")))
                score = 90;
            else if (icon && icon === needle)
                score = 80;
            else if (start && start.length >= 4 && (needle === start || needle.indexOf(start) === 0 || start.indexOf(needle) === 0))
                score = 70;
            else if (id && id.length >= 4 && (id === needle || needle.indexOf(id) === 0))
                score = 60;
            else if (name && name.length >= 4 && name === needle.replace(/-/g, ""))
                score = 50;
            if (score > bestScore) {
                bestScore = score;
                best = e;
            }
        }

        return best;
    }

    function gameAssetIcon(blob) {
        const s = String(blob || "").toLowerCase();
        if (s.indexOf("terraria") !== -1 || s.indexOf("105600") !== -1)
            return "file://" + Quickshell.shellDir + "/assets/games/terraria.png";
        return "";
    }

    function iconFromEntry(entry) {
        if (!entry)
            return "";
        if (root.isMainFileManager(entry))
            return root.finderIcon;
        if (root.isKeymapp(entry))
            return root.keymappIcon;
        if (root.isSatty(entry))
            return root.sattyIcon;
        if (root.isKitty(entry))
            return root.kittyIcon;
        if (root.isAmnezia(entry))
            return root.amneziaIcon;
        if (entry.icon)
            return root.resolveIcon(entry.icon, "application-x-executable");
        return "";
    }

    function iconPathForClass(cls, title) {
        const clsStr = String(cls || "");
        const titleStr = String(title || "");
        const needle = clsStr.toLowerCase();
        if (needle.indexOf("kitty") !== -1 || titleStr.toLowerCase().indexOf("kitty") !== -1)
            return root.kittyIcon;
        if (needle.indexOf("amnezia") !== -1 || titleStr.toLowerCase().indexOf("amnezia") !== -1)
            return root.amneziaIcon;

        const asset = root.gameAssetIcon(clsStr + " " + titleStr);
        if (asset)
            return asset;

        const steamId = root.steamIdFromClass(clsStr);
        if (steamId) {
            const fromSteam = root.iconFromEntry(root.entryForSteamId(steamId));
            if (fromSteam)
                return fromSteam;
            return Quickshell.iconPath("steam_icon_" + steamId, "steam");
        }

        if (needle.indexOf("gamescope") !== -1) {
            const fromTitle = root.iconFromEntry(root.entryForTitle(titleStr));
            if (fromTitle)
                return fromTitle;
            return Quickshell.iconPath("input-gaming", "application-x-executable");
        }

        const entry = root.entryForClass(clsStr) || root.entryForTitle(titleStr);
        const fromEntry = root.iconFromEntry(entry);
        if (fromEntry)
            return fromEntry;
        if (needle.indexOf("keymapp") !== -1)
            return root.keymappIcon;
        if (needle.indexOf("satty") !== -1)
            return root.sattyIcon;
        if (needle.indexOf("kitty") !== -1)
            return root.kittyIcon;
        if (needle.indexOf("amnezia") !== -1)
            return root.amneziaIcon;
        if (needle && needle !== "cursor")
            return Quickshell.iconPath(needle, "application-x-executable");
        return Quickshell.iconPath("application-x-executable");
    }

    function iconPathForWindow(t) {
        if (!t)
            return Quickshell.iconPath("application-x-executable");
        const ipc = t.lastIpcObject || {};
        return root.iconPathForClass(ipc.class || ipc.initialClass || ipc.initial_class || "", t.title || ipc.title || "");
    }

    function nameForClass(cls, fallback) {
        const entry = root.entryForClass(cls);
        if (entry && root.isMainFileManager(entry))
            return "Finder";
        if (entry && entry.name)
            return entry.name;
        return fallback || cls || "Window";
    }

    Component.onCompleted: {
        root.loadUsage()
        root.loadLayout()
        root.rebuildEntries()
    }
}
