pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../core" as Core

// Aurora Apps Service
//
// Application list and ranking for the launcher.
// Usage:  ~/.cache/aurora/launcher-usage.json
// Layout: ~/.local/state/aurora/app-layout.json  (not under HM-managed ~/.config)

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string usagePath: root.home + "/.cache/aurora/launcher-usage.json"
    readonly property string layoutPath: root.home + "/.local/state/aurora/app-layout.json"
    readonly property string layoutBackupPath: root.home + "/.local/state/aurora/app-layout.backup.json"
    readonly property string layoutLegacyConfigPath: root.home + "/.config/aurora/app-layout.json"
    readonly property string layoutLegacyCachePath: root.home + "/.cache/aurora/app-layout.json"

    property var usage: ({})
    property var launchpadOrder: []
    property var dockOrder: []
    property bool dockConfigured: false
    property bool layoutReady: false
    property bool layoutHydrated: false
    property bool layoutWriting: false
    property string openFolderId: ""

    readonly property var defaultDockNeedles: ["firefox", "zen", "google-chrome", "kitty", "thunar", "nemo", "cursor", "code", "obsidian", "idea-ultimate", "idea", "steam", "xournal", "telegram", "discord"]

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
        onFileChanged: {
            if (root.layoutWriting)
                return;
            this.reload();
        }
        onLoaded: root.loadLayout()
    }

    property FileView layoutBackupFile: FileView {
        path: root.layoutBackupPath
        blockLoading: true
        printErrors: false
    }

    property FileView layoutLegacyConfigFile: FileView {
        path: root.layoutLegacyConfigPath
        blockLoading: true
        printErrors: false
    }

    property FileView layoutLegacyCacheFile: FileView {
        path: root.layoutLegacyCachePath
        blockLoading: true
        printErrors: false
    }

    property Timer layoutWriteUnlock: Timer {
        interval: 800
        repeat: false
        onTriggered: root.layoutWriting = false
    }

    function readLayoutRaw() {
        const primary = root.layoutFile.text();
        if (primary && primary.length)
            return primary;
        const backup = root.layoutBackupFile.text();
        if (backup && backup.length)
            return backup;
        const cfg = root.layoutLegacyConfigFile.text();
        if (cfg && cfg.length)
            return cfg;
        const cache = root.layoutLegacyCacheFile.text();
        if (cache && cache.length)
            return cache;
        return "";
    }

    function loadUsage() {
        const raw = root.usageFile.text();
        if (!raw) {
            root.usage = ({});
            return;
        }

        try {
            const parsed = JSON.parse(raw);
            root.usage = (parsed && typeof parsed === "object") ? parsed : ({});
        } catch (e) {
            root.usage = ({});
        }
    }

    function bump(id) {
        if (!id || id.length === 0)
            return;

        // Copy, then mutate, then assign.
        const next = ({});
        const keys = Object.keys(root.usage);

        for (let i = 0; i < keys.length; i++)
            next[keys[i]] = root.usage[keys[i]];

        next[id] = (next[id] || 0) + 1;
        root.usage = next;

        root.usageFile.setText(JSON.stringify(next));
    }

    function loadLayout() {
        if (root.layoutWriting)
            return;
        const raw = root.readLayoutRaw();
        if (!raw) {
            // Empty read during FileView races must not wipe in-memory pins
            // after a hot reload / flake rebuild.
            if (root.launchpadOrder.length || root.dockOrder.length) {
                root.layoutReady = true;
                root.layoutHydrated = true;
                return;
            }
            root.layoutReady = true;
            root.layoutHydrated = true;
            return;
        }

        try {
            const parsed = JSON.parse(raw);
            const nextLp = root.normalizeLaunchpad(parsed && parsed.launchpad);
            const nextDock = root.normalizeDock(parsed && parsed.dock);
            // Prefer richer disk layout over a transient empty memory state.
            if (nextLp.length || nextDock.length || !root.launchpadOrder.length) {
                root.launchpadOrder = nextLp;
                root.dockOrder = nextDock;
                root.dockConfigured = parsed && Object.prototype.hasOwnProperty.call(parsed, "dock");
            }
            // Migrate off HM-touched ~/.config and ensure state+backup exist.
            if (root.launchpadOrder.length && root.layoutFile.text() !== raw)
                root.saveLayout(true);
            else if (root.launchpadOrder.length && !root.layoutBackupFile.text())
                root.saveLayout(true);
        } catch (e) {
            if (!root.launchpadOrder.length) {
                root.launchpadOrder = [];
                root.dockOrder = [];
                root.dockConfigured = false;
            }
        }
        root.layoutReady = true;
        root.layoutHydrated = true;
    }

    function isFolderTile(item) {
        return !!(item && typeof item === "object" && Array.isArray(item.apps));
    }

    function tileId(item) {
        if (typeof item === "string")
            return item;
        if (root.isFolderTile(item) && item.id)
            return String(item.id);
        return "";
    }

    function cloneTile(item) {
        if (typeof item === "string")
            return item;
        if (!root.isFolderTile(item))
            return item;
        return {
            "id": String(item.id || ""),
            "name": String(item.name || "Folder"),
            "apps": (item.apps || []).map(String)
        };
    }

    function normalizeLaunchpad(raw) {
        const src = Array.isArray(raw) ? raw : [];
        const out = [];
        const seen = ({});
        for (let i = 0; i < src.length; i++) {
            const item = src[i];
            if (typeof item === "string") {
                const id = root.canonicalAppId(item);
                if (!id || seen["app:" + id])
                    continue;
                seen["app:" + id] = true;
                out.push(id);
                continue;
            }
            if (!root.isFolderTile(item))
                continue;
            const fid = String(item.id || "");
            if (!fid || seen["folder:" + fid])
                continue;
            const apps = [];
            const appSeen = ({});
            const list = item.apps || [];
            for (let a = 0; a < list.length; a++) {
                const id = root.canonicalAppId(list[a] || "");
                if (!id || appSeen[id] || seen["app:" + id])
                    continue;
                appSeen[id] = true;
                seen["app:" + id] = true;
                apps.push(id);
            }
            if (apps.length === 1) {
                out.push(apps[0]);
                continue;
            }
            if (apps.length === 0)
                continue;
            seen["folder:" + fid] = true;
            out.push({
                "id": fid,
                "name": String(item.name || "Folder"),
                "apps": apps
            });
        }
        return out;
    }

    function normalizeDock(raw) {
        const src = Array.isArray(raw) ? raw : [];
        const out = [];
        const seen = ({});
        for (let i = 0; i < src.length; i++) {
            const id = root.canonicalAppId(src[i]);
            if (!id || seen[id])
                continue;
            seen[id] = true;
            out.push(id);
        }
        return out;
    }

    function serializeLaunchpad() {
        const out = [];
        const src = root.launchpadOrder || [];
        for (let i = 0; i < src.length; i++) {
            const item = src[i];
            if (typeof item === "string")
                out.push(item);
            else if (root.isFolderTile(item))
                out.push({
                    "id": String(item.id),
                    "name": String(item.name || "Folder"),
                    "apps": (item.apps || []).map(String)
                });
        }
        return out;
    }

    function newFolderId() {
        return "folder-" + Date.now() + "-" + Math.floor(Math.random() * 100000);
    }

    function findFolder(id) {
        const needle = String(id || "");
        const src = root.launchpadOrder || [];
        for (let i = 0; i < src.length; i++) {
            if (root.isFolderTile(src[i]) && String(src[i].id) === needle)
                return src[i];
        }
        return null;
    }

    function saveLayout(userEdit) {
        // Refuse to persist an empty grid — that is how hot-reload races wipe pins.
        if (!root.launchpadOrder.length && !root.dockOrder.length)
            return;
        root.dockConfigured = true;
        const text = JSON.stringify({
            "launchpad": root.serializeLaunchpad(),
            "dock": root.dockOrder
        });
        root.layoutWriting = true;
        root.layoutWriteUnlock.restart();
        root.layoutFile.setText(text);
        // Sacred copy: always refresh backup when we intentionally save.
        root.layoutBackupFile.setText(text);
    }

    function sameIds(a, b) {
        if (!a || !b || a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] !== b[i])
                return false;
        }
        return true;
    }

    function resolveStoredId(id) {
        const needle = String(id || "");
        if (!needle)
            return "";
        const lower = needle.toLowerCase().replace(/\.desktop$/, "");
        if (lower === "com.google.chrome" || lower === "chrome-dd")
            return "google-chrome";
        const compact = lower.replace(/[^a-z0-9]/g, "");
        const list = root.entries;
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            const eid = String(e && e.id || "");
            if (!eid)
                continue;
            const el = eid.toLowerCase().replace(/\.desktop$/, "");
            if (el === lower)
                return eid;
        }
        if (compact.length >= 3) {
            for (let i = 0; i < list.length; i++) {
                const e = list[i];
                const eid = String(e && e.id || "");
                if (!eid)
                    continue;
                const ec = eid.toLowerCase().replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "");
                if (ec === compact || (compact.length >= 5 && (ec.indexOf(compact) !== -1 || compact.indexOf(ec) !== -1)))
                    return eid;
            }
        }
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            const eid = String(e && e.id || "");
            if (!eid)
                continue;
            if (root.haystack(e).indexOf(lower) !== -1)
                return eid;
        }
        return "";
    }

    function defaultDockIds(entries) {
        const ids = [];
        const seen = {};
        const list = entries || root.entries;
        for (let n = 0; n < root.defaultDockNeedles.length; n++) {
            const needle = root.defaultDockNeedles[n];
            for (let i = 0; i < list.length; i++) {
                const e = list[i];
                const id = e && e.id ? String(e.id) : "";
                if (!id || seen[id])
                    continue;
                const hay = [id, String(e.name || ""), String(e.execString || e.exec || ""), String(e.startupClass || "")].join(" ").toLowerCase();
                if (hay.indexOf(needle) === -1)
                    continue;
                seen[id] = true;
                ids.push(id);
                break;
            }
        }
        return ids;
    }

    function syncLayout() {
        const list = root.entries;
        if (!list.length)
            return;
        if (!root.layoutHydrated || !root.layoutReady)
            root.loadLayout();

        // Hot reload / flake rebuild starts with empty memory. Rehydrate from
        // disk/backup and never invent an alphabetical grid on top of pins.
        if (!root.launchpadOrder.length) {
            root.loadLayout();
            if (!root.launchpadOrder.length) {
                const disk = root.readLayoutRaw();
                if (disk && disk.length > 2)
                    return;
            }
        }

        const have = ({});
        for (let i = 0; i < list.length; i++) {
            const id = list[i] && list[i].id ? String(list[i].id) : "";
            if (id)
                have[id] = true;
        }

        // Full catalog only: partial waves after a flake rebuild used to drop
        // every pin not yet scanned and rewrite launchpad in alpha order.
        const catalogWarm = list.length >= 12;
        const pruneMissing = list.length >= 40;
        const hadPins = root.launchpadOrder.length > 0;
        const diskHadPins = !!(root.readLayoutRaw() && root.readLayoutRaw().length > 2);

        const lp = [];
        const seenLp = {};
        const prevLp = root.launchpadOrder;
        for (let i = 0; i < prevLp.length; i++) {
            const item = root.cloneTile(prevLp[i]);
            if (typeof item === "string") {
                const raw = String(item || "");
                if (!raw)
                    continue;
                const id = root.resolveStoredId(raw) || raw;
                if (seenLp["app:" + id] || seenLp["app:" + raw])
                    continue;
                const known = !!(have[id] || have[raw]);
                if (!known && pruneMissing)
                    continue;
                seenLp["app:" + id] = true;
                seenLp["app:" + raw] = true;
                lp.push(known ? id : raw);
                continue;
            }
            if (!root.isFolderTile(item))
                continue;
            const apps = [];
            for (let a = 0; a < item.apps.length; a++) {
                const raw = String(item.apps[a] || "");
                if (!raw)
                    continue;
                const id = root.resolveStoredId(raw) || raw;
                if (seenLp["app:" + id] || seenLp["app:" + raw])
                    continue;
                const known = !!(have[id] || have[raw]);
                if (!known && pruneMissing)
                    continue;
                seenLp["app:" + id] = true;
                seenLp["app:" + raw] = true;
                apps.push(known ? id : raw);
            }
            if (apps.length === 1) {
                lp.push(apps[0]);
                continue;
            }
            if (apps.length === 0)
                continue;
            item.apps = apps;
            seenLp["folder:" + item.id] = true;
            lp.push(item);
        }
        if (catalogWarm) {
            for (let i = 0; i < list.length; i++) {
                const id = list[i] && list[i].id ? String(list[i].id) : "";
                if (!id || seenLp["app:" + id])
                    continue;
                seenLp["app:" + id] = true;
                lp.push(id);
            }
        }

        const dock = [];
        const seenDock = {};
        const prevDock = root.dockOrder || [];
        for (let i = 0; i < prevDock.length; i++) {
            const raw = String(prevDock[i] || "");
            if (!raw || seenDock[raw])
                continue;
            if (raw.indexOf("folder-") === 0) {
                seenDock[raw] = true;
                dock.push(raw);
                continue;
            }
            const id = root.resolveStoredId(raw) || raw;
            if (!id || seenDock[id])
                continue;
            const known = !!(have[id] || have[raw]);
            if (!known && pruneMissing)
                continue;
            seenDock[id] = true;
            seenDock[raw] = true;
            dock.push(known ? id : raw);
        }

        let dockChanged = false;
        if (dock.length === 0 && !root.dockConfigured) {
            const defaults = root.defaultDockIds(list);
            if (defaults.length) {
                root.dockOrder = defaults;
                root.dockConfigured = true;
                dockChanged = true;
            }
        } else if (dock.length < prevDock.length && prevDock.length > 2) {
            // Desktop entries arrive in waves. A short catalog used to persist
            // an empty dock and wipe pins across restarts.
        } else if (!root.sameIds(root.dockOrder, dock)) {
            root.dockOrder = dock;
            dockChanged = true;
        }

        // Same wave-guard for launchpad: never persist a shrunk grid.
        const lpShrunk = prevLp.length > 2 && lp.length < prevLp.length;
        const lpChanged = !lpShrunk && !root.sameLaunchpad(root.launchpadOrder, lp);
        if (lpChanged)
            root.launchpadOrder = lp;

        // CRITICAL: sync must not rewrite the on-disk layout after rebuilds.
        // Empty-memory → full catalog dumps were wiping folders/pins. Only seed
        // the file when it truly does not exist yet.
        const seeding = !hadPins && !diskHadPins && root.launchpadOrder.length > 0;
        if (seeding || (dockChanged && !diskHadPins && !hadPins))
            root.saveLayout(true);
    }

    function sameLaunchpad(a, b) {
        if (!a || !b || a.length !== b.length)
            return false;
        for (let i = 0; i < a.length; i++) {
            const left = a[i];
            const right = b[i];
            if (typeof left === "string" || typeof right === "string") {
                if (left !== right)
                    return false;
                continue;
            }
            if (!root.isFolderTile(left) || !root.isFolderTile(right))
                return false;
            if (String(left.id) !== String(right.id) || String(left.name) !== String(right.name))
                return false;
            if (!root.sameIds(left.apps || [], right.apps || []))
                return false;
        }
        return true;
    }

    function byIdMap() {
        const map = ({});
        const list = root.entries;
        for (let i = 0; i < list.length; i++) {
            const e = list[i];
            if (e && e.id)
                map[String(e.id)] = e;
        }
        return map;
    }

    readonly property var launchpadTiles: {
        const order = root.launchpadOrder;
        const _n = order ? order.length : 0;
        const _e = root.entries.length;
        const map = root.byIdMap();
        const out = [];
        for (let i = 0; i < _n; i++) {
            const item = order[i];
            if (typeof item === "string") {
                const id = root.resolveStoredId(item) || item;
                const e = map[id] || map[item];
                if (e)
                    out.push({
                        "type": "app",
                        "id": String(e.id || id),
                        "name": root.displayName(e),
                        "entry": e,
                        "apps": []
                    });
                continue;
            }
            if (!root.isFolderTile(item))
                continue;
            const apps = [];
            const ids = item.apps || [];
            for (let a = 0; a < ids.length; a++) {
                const raw = String(ids[a] || "");
                const id = root.resolveStoredId(raw) || raw;
                const e = map[id] || map[raw];
                if (e)
                    apps.push(e);
            }
            if (apps.length < 2)
                continue;
            out.push({
                "type": "folder",
                "id": String(item.id),
                "name": String(item.name || "Folder"),
                "entry": null,
                "apps": apps
            });
        }
        return out;
    }

    readonly property var dockTiles: {
        const order = root.dockOrder;
        const _n = order ? order.length : 0;
        const _e = root.entries.length;
        const map = root.byIdMap();
        const folders = ({});
        const lp = root.launchpadTiles;
        for (let i = 0; i < lp.length; i++) {
            if (lp[i].type === "folder")
                folders[lp[i].id] = lp[i];
        }
        const out = [];
        for (let i = 0; i < _n; i++) {
            const raw = String(order[i] || "");
            if (!raw)
                continue;
            if (folders[raw]) {
                out.push(folders[raw]);
                continue;
            }
            const id = root.resolveStoredId(raw) || raw;
            if (folders[id]) {
                out.push(folders[id]);
                continue;
            }
            const e = map[id] || map[raw];
            if (e)
                out.push({
                    "type": "app",
                    "id": String(e.id || id),
                    "name": root.displayName(e),
                    "entry": e,
                    "apps": []
                });
        }
        return out;
    }

    readonly property var openFolder: {
        const id = String(root.openFolderId || "");
        if (!id)
            return null;
        const tiles = root.launchpadTiles;
        for (let i = 0; i < tiles.length; i++) {
            if (tiles[i].type === "folder" && tiles[i].id === id)
                return tiles[i];
        }
        return null;
    }

    function moveIds(ids, from, to) {
        const next = ids.slice();
        if (from < 0 || from >= next.length)
            return ids;
        const dest = Math.max(0, Math.min(next.length - 1, to));
        if (from === dest)
            return ids;
        const item = next.splice(from, 1)[0];
        next.splice(dest, 0, item);
        return next;
    }

    function moveVisibleIds(visible, from, to, stored) {
        const ids = [];
        for (let i = 0; i < visible.length; i++) {
            const id = visible[i] && visible[i].id ? String(visible[i].id) : "";
            if (id)
                ids.push(id);
        }
        const nextVisible = root.moveIds(ids, from, to);
        const seen = ({});
        for (let i = 0; i < nextVisible.length; i++)
            seen[String(nextVisible[i])] = true;
        const rest = [];
        const prev = stored || [];
        for (let i = 0; i < prev.length; i++) {
            const id = String(prev[i] || "");
            if (id && !seen[id])
                rest.push(id);
        }
        return nextVisible.concat(rest);
    }

    function orderIndexOfTile(tile) {
        if (!tile)
            return -1;
        const src = root.launchpadOrder || [];
        const id = String(tile.id || "");
        if (!id)
            return -1;
        for (let i = 0; i < src.length; i++) {
            if (tile.type === "folder") {
                if (root.isFolderTile(src[i]) && String(src[i].id) === id)
                    return i;
            } else if (typeof src[i] === "string" && (String(src[i]) === id || root.resolveStoredId(src[i]) === id)) {
                return i;
            }
        }
        return -1;
    }

    function moveLaunchpad(from, to) {
        const tiles = root.launchpadTiles;
        if (from < 0 || to < 0 || from >= tiles.length || to >= tiles.length)
            return;
        const fromOrder = root.orderIndexOfTile(tiles[from]);
        const toOrder = root.orderIndexOfTile(tiles[to]);
        if (fromOrder < 0 || toOrder < 0 || fromOrder === toOrder)
            return;
        const next = root.launchpadOrder.slice();
        const dest = Math.max(0, Math.min(next.length - 1, toOrder));
        const item = next.splice(fromOrder, 1)[0];
        next.splice(Math.max(0, Math.min(next.length, dest)), 0, item);
        if (root.sameLaunchpad(next, root.launchpadOrder))
            return;
        root.launchpadOrder = next;
        root.saveLayout();
    }

    function mergeLaunchpad(from, to) {
        const tiles = root.launchpadTiles;
        if (from < 0 || to < 0 || from === to)
            return;
        if (from >= tiles.length || to >= tiles.length)
            return;
        const movingTile = tiles[from];
        const targetTile = tiles[to];
        const fromOrder = root.orderIndexOfTile(movingTile);
        const toOrder = root.orderIndexOfTile(targetTile);
        if (fromOrder < 0 || toOrder < 0)
            return;
        const src = root.launchpadOrder.slice();
        const moving = root.cloneTile(src[fromOrder]);
        const target = root.cloneTile(src[toOrder]);
        if (root.isFolderTile(moving)) {
            root.moveLaunchpad(from, to);
            return;
        }
        const appId = root.tileId(moving) || String(movingTile.id || "");
        if (!appId)
            return;
        if (root.isFolderTile(target)) {
            const apps = (target.apps || []).map(String);
            if (apps.indexOf(appId) < 0)
                apps.push(appId);
            target.apps = apps;
            src[toOrder] = target;
            src.splice(fromOrder, 1);
            root.launchpadOrder = root.normalizeLaunchpad(src);
            root.saveLayout();
            return;
        }
        const otherId = root.tileId(target) || String(targetTile.id || "");
        if (!otherId || otherId === appId)
            return;
        const folder = {
            "id": root.newFolderId(),
            "name": "Folder",
            "apps": [otherId, appId]
        };
        const insertAt = fromOrder < toOrder ? toOrder - 1 : toOrder;
        const next = [];
        for (let i = 0; i < src.length; i++) {
            if (i === fromOrder || i === toOrder)
                continue;
            next.push(src[i]);
        }
        next.splice(Math.max(0, Math.min(next.length, insertAt)), 0, folder);
        root.launchpadOrder = root.normalizeLaunchpad(next);
        root.openFolderId = folder.id;
        root.saveLayout();
    }

    function renameFolder(id, name) {
        const needle = String(id || "");
        const label = String(name || "").trim() || "Folder";
        const src = root.launchpadOrder.slice();
        let changed = false;
        for (let i = 0; i < src.length; i++) {
            if (root.isFolderTile(src[i]) && String(src[i].id) === needle) {
                const tile = root.cloneTile(src[i]);
                tile.name = label;
                src[i] = tile;
                changed = true;
                break;
            }
        }
        if (!changed)
            return;
        root.launchpadOrder = src;
        root.saveLayout();
    }

    function moveInFolder(folderId, from, to) {
        const fid = String(folderId || "");
        const src = root.launchpadOrder.slice();
        for (let i = 0; i < src.length; i++) {
            if (!root.isFolderTile(src[i]) || String(src[i].id) !== fid)
                continue;
            const tile = root.cloneTile(src[i]);
            const apps = (tile.apps || []).map(String);
            const next = root.moveIds(apps, from, to);
            if (root.sameIds(next, apps))
                return;
            tile.apps = next;
            src[i] = tile;
            root.launchpadOrder = src;
            root.saveLayout();
            return;
        }
    }

    function removeFromFolder(folderId, appId) {
        const fid = String(folderId || "");
        const aid = String(appId || "");
        const src = root.launchpadOrder.slice();
        let folderIndex = -1;
        for (let i = 0; i < src.length; i++) {
            if (!root.isFolderTile(src[i]) || String(src[i].id) !== fid)
                continue;
            folderIndex = i;
            const tile = root.cloneTile(src[i]);
            tile.apps = (tile.apps || []).filter(function (id) {
                return String(id) !== aid;
            });
            src[i] = tile;
            break;
        }
        if (folderIndex < 0)
            return;
        src.splice(folderIndex + 1, 0, aid);
        root.launchpadOrder = root.normalizeLaunchpad(src);
        if (!root.findFolder(fid))
            root.openFolderId = "";
        root.saveLayout();
    }

    function closeFolder() {
        root.openFolderId = "";
    }

    function toggleFolder(id) {
        const needle = String(id || "");
        root.openFolderId = root.openFolderId === needle ? "" : needle;
    }

    function moveDock(from, to) {
        const next = root.moveVisibleIds(root.dockTiles, from, to, root.dockOrder);
        if (root.sameIds(next, root.dockOrder))
            return;
        root.dockOrder = next;
        root.saveLayout();
    }

    function toggleDockPin(id) {
        const needle = String(id || "");
        if (!needle)
            return;
        const dock = root.dockOrder.slice();
        const idx = dock.indexOf(needle);
        if (idx >= 0)
            dock.splice(idx, 1);
        else
            dock.push(needle);
        root.dockOrder = dock;
        root.saveLayout();
    }

    property bool dockDropActive: false
    property int dockHoverSlot: -1
    property bool launchpadDragging: false

    function clearDockDrop() {
        root.dockDropActive = false;
        root.dockHoverSlot = -1;
        root.launchpadDragging = false;
    }

    function pinDock(id, at) {
        const needle = String(id || "");
        if (!needle)
            return;
        const dock = root.dockOrder.filter(function (item) {
            return String(item) !== needle;
        });
        let dest = dock.length;
        if (typeof at === "number" && at >= 0)
            dest = Math.max(0, Math.min(dock.length, at));
        dock.splice(dest, 0, needle);
        if (root.sameIds(dock, root.dockOrder))
            return;
        root.dockOrder = dock;
        root.saveLayout();
    }

    function unpinDock(id) {
        const needle = String(id || "");
        if (!needle)
            return;
        const dock = root.dockOrder.filter(function (item) {
            return String(item) !== needle;
        });
        if (root.sameIds(dock, root.dockOrder))
            return;
        root.dockOrder = dock;
        root.saveLayout();
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
    readonly property string obsidianIcon: "file://" + Quickshell.shellDir + "/assets/obsidian.png"
    readonly property string chromeIcon: "file://" + Quickshell.shellDir + "/assets/google-chrome.png"

    function haystack(entry) {
        return [entry.id, entry.name, entry.execString, entry.exec, entry.startupClass, entry.startupWmClass, entry.icon].join(" ").toLowerCase();
    }

    function isGuiApp(entry) {
        if (entry.runInTerminal === true || entry.terminal === true)
            return false;

        const cats = entry.categories;
        if (cats) {
            for (let i = 0; i < cats.length; i++) {
                const cat = String(cats[i]).toLowerCase();
                if (cat === "consoleonly")
                    return false;
            }
        }

        return true;
    }

    function isJunk(entry) {
        const text = root.haystack(entry);
        const deny = ["kvantum", "qt5ct", "qt6ct", "qv4l2", "qvidcap", "nm-connection", "uuctl", "pavucontrol", "zathura", "amneziavpn", "wine-extension", "wine-protocol"];

        for (let i = 0; i < deny.length; i++) {
            if (text.indexOf(deny[i]) !== -1)
                return true;
        }

        const id = String(entry && entry.id || "").replace(/\.desktop$/i, "");
        if (id === "Overwatch" || id === "Terraria" || id === "Albion Online" || id === "org.telegram.desktop")
            return true;
        const exec = String(entry && (entry.execString || entry.exec) || "");
        if (exec.indexOf("steam://rungameid/2357570") !== -1 || exec.indexOf("steam://rungameid/105600") !== -1 || exec.indexOf("steam://rungameid/761890") !== -1)
            return true;

        return false;
    }

    function isFileManager(entry) {
        const text = root.haystack(entry);
        if (text.indexOf("thunar") !== -1)
            return true;

        const cats = entry.categories;
        if (cats) {
            for (let i = 0; i < cats.length; i++) {
                if (String(cats[i]).toLowerCase() === "filemanager")
                    return true;
            }
        }

        return false;
    }

    function isMainFileManager(entry) {
        const id = String(entry.id || "").toLowerCase().replace(/\.desktop$/, "");
        return id === "thunar";
    }

    function canonicalAppId(id) {
        const low = String(id || "").toLowerCase().replace(/\.desktop$/, "");
        if (low === "org.xfce.thunar" || low === "finder")
            return "thunar";
        if (low === "writer")
            return "libreoffice-writer";
        if (low === "calc")
            return "libreoffice-calc";
        if (low === "impress")
            return "libreoffice-impress";
        if (low === "draw")
            return "libreoffice-draw";
        if (low === "startcenter")
            return "libreoffice-startcenter";
        if (low === "code-url-handler")
            return "code";
        if (low === "com.google.chrome" || low === "chrome-dd" || low === "google-chrome")
            return "google-chrome";
        if (low === "albion online" || low === "albiononline" || low === "albion")
            return "albion-online";
        if (low === "overwatch" || low === "overwatch®" || low === "steam_app_2357570")
            return "overwatch";
        if (low === "terraria" || low === "steam_app_105600")
            return "terraria";
        return String(id || "").replace(/\.desktop$/i, "");
    }

    function isKeymapp(entry) {
        const text = root.haystack(entry);
        return text.indexOf("keymapp") !== -1;
    }

    function isSatty(entry) {
        return root.haystack(entry).indexOf("satty") !== -1;
    }

    function isObsidian(entry) {
        return root.haystack(entry).indexOf("obsidian") !== -1;
    }

    function isChrome(entry) {
        if (!entry)
            return false;
        const id = String(entry.id || "").toLowerCase().replace(/\.desktop$/, "");
        if (id === "google-chrome" || id === "com.google.chrome" || id === "chrome-dd" || id === "chrome-az" || id === "chrome-hika" || id === "chrome-sciencesoft")
            return true;
        const hay = root.haystack(entry);
        return hay.indexOf("google-chrome") !== -1 || hay.indexOf("chrome-dd") !== -1 || hay.indexOf("chrome-az") !== -1 || hay.indexOf("chrome-hika") !== -1 || hay.indexOf("chrome-sciencesoft") !== -1;
    }

    function isKitty(entry) {
        if (!entry)
            return false;
        const blob = root.haystack(entry);
        const icon = String(entry.icon || "").toLowerCase();
        return blob.indexOf("kitty") !== -1 || icon.indexOf("kitty") !== -1;
    }

    function isDiscord(entry) {
        if (!entry)
            return false;
        const id = String(entry.id || "").toLowerCase();
        if (id === "discord" || id.indexOf("discord") !== -1 || id.indexOf("vesktop") !== -1)
            return true;
        const hay = root.haystack(entry);
        return hay.indexOf("discord") !== -1 || hay.indexOf("vesktop") !== -1;
    }

    function isAmnezia(entry) {
        if (!entry)
            return false;
        return root.haystack(entry).indexOf("amnezia") !== -1;
    }

    function isSpotify(entry) {
        if (!entry)
            return false;
        const id = String(entry.id || "").toLowerCase();
        if (id === "spotify" || id.indexOf("spotify") !== -1)
            return true;
        return root.haystack(entry).indexOf("spotify") !== -1;
    }

    function isInsta360(entry) {
        if (!entry)
            return false;
        return root.haystack(entry).indexOf("insta360") !== -1;
    }

    function isIdea(entry) {
        if (!entry)
            return false;
        const id = String(entry.id || "").toLowerCase().replace(/\.desktop$/, "");
        if (id === "idea-ultimate" || id === "idea" || id === "intellij-idea" || id.indexOf("idea-ultimate") !== -1)
            return true;
        const start = String(entry.startupWmClass || entry.startupClass || entry.wmClass || "").toLowerCase();
        if (start === "jetbrains-idea" || start === "jetbrains-idea-ce")
            return true;
        const name = String(entry.name || "").toLowerCase().trim();
        if (name.indexOf("intellij") !== -1 || name === "idea" || name.indexOf("idea ultimate") !== -1)
            return true;
        const exec = String(entry.execString || entry.exec || "").toLowerCase();
        if (exec.indexOf("idea-ultimate") !== -1 || exec.indexOf("idea-ultimate.sh") !== -1)
            return true;
        return false;
    }

    function isCursor(entry) {
        if (!entry)
            return false;
        const id = String(entry.id || "").toLowerCase().replace(/\.desktop$/, "");
        if (id === "cursor" || id === "code-cursor")
            return true;
        const start = String(entry.startupWmClass || entry.startupClass || entry.wmClass || "").toLowerCase();
        if (start === "cursor")
            return true;
        const name = String(entry.name || "").toLowerCase().trim();
        if (name === "cursor")
            return true;
        const exec = String(entry.execString || entry.exec || "").toLowerCase();
        if (exec.indexOf("cursor.sh") !== -1 || exec.indexOf("code-cursor") !== -1 || exec.indexOf("/bin/cursor") !== -1)
            return true;
        if (/(^|[\\s'\"\\/])cursor(\\s|$)/.test(exec) && exec.indexOf("set-cursor") < 0 && exec.indexOf("load-cursor") < 0)
            return true;
        return false;
    }

    function isObs(entry) {
        if (!entry)
            return false;
        const id = String(entry.id || "").toLowerCase().replace(/\.desktop$/, "");
        if (id === "com.obsproject.studio" || id === "obs-studio" || id === "obs")
            return true;
        const start = String(entry.startupWmClass || entry.startupClass || entry.wmClass || "").toLowerCase();
        if (start === "obs" || start === "com.obsproject.studio")
            return true;
        const name = String(entry.name || "").toLowerCase().trim();
        if (name === "obs studio" || name === "obs")
            return true;
        const exec = String(entry.execString || entry.exec || "").toLowerCase();
        // Wrapper path, nix binary, or bare name — never miss launcher tiles.
        if (exec.indexOf("obs.sh") !== -1 || exec.indexOf("/bin/obs") !== -1 || exec.indexOf("obs-studio") !== -1 || /(^|[\\s\\/])obs(\\s|$)/.test(exec))
            return true;
        return false;
    }

    function resolveIcon(icon, fallback) {
        const name = String(icon || "");
        const fb = fallback || "application-x-executable";
        if (name.toLowerCase().indexOf("obsidian") !== -1)
            return root.obsidianIcon;
        if (name.toLowerCase().indexOf("google-chrome") !== -1 || name.toLowerCase() === "chrome-dd" || name.toLowerCase() === "chrome-az" || name.toLowerCase() === "chrome-hika" || name.toLowerCase() === "chrome-sciencesoft")
            return root.chromeIcon;
        if (!name)
            return Quickshell.iconPath(fb);
        if (name.indexOf("://") >= 0)
            return name;
        if (name.charAt(0) === "/")
            return "file://" + name;
        const path = Quickshell.iconPath(name, fb);
        if (path)
            return path;
        const base = name.split(".").pop().replace(/\.desktop$/, "");
        if (base && base !== name) {
            const alt = Quickshell.iconPath(base, fb);
            if (alt)
                return alt;
        }
        return Quickshell.iconPath(fb);
    }

    function iconSource(entry) {
        if (!entry)
            return Quickshell.iconPath("application-x-executable");
        if (root.isMainFileManager(entry))
            return root.finderIcon;
        if (root.isKeymapp(entry))
            return root.keymappIcon;
        if (root.isSatty(entry))
            return root.sattyIcon;
        if (root.isObsidian(entry))
            return root.obsidianIcon;
        if (root.isChrome(entry))
            return root.chromeIcon;
        if (root.isKitty(entry))
            return root.kittyIcon;
        if (root.isAmnezia(entry))
            return root.amneziaIcon;
        return root.resolveIcon(entry.icon, "application-x-executable");
    }

    function displayName(entry) {
        if (root.isMainFileManager(entry))
            return "Finder";
        return entry && entry.name ? entry.name : "App";
    }

    function steamAppId(entry) {
        const exec = String(entry && (entry.execString || entry.exec) || "").toLowerCase();
        const match = exec.match(/rungameid\/(\d+)/);
        return match ? match[1] : "";
    }

    function rebuildEntries() {
        const source = DesktopEntries.applications.values;
        if (!source || source.length === 0)
            return;
        const out = [];
        const seenSteam = {};
        const seenName = {};
        const seenId = {};

        for (let i = 0; i < source.length; i++) {
            const entry = source[i];
            if (!entry)
                continue;
            if (entry.noDisplay === true || entry.hidden === true)
                continue;
            if (!entry.name || entry.name.length === 0)
                continue;
            if (String(entry.name) === "Hidden")
                continue;
            const execLine = String(entry.execString || entry.exec || "").trim();
            if (execLine === "true" || execLine === "/usr/bin/true" || execLine === "/bin/true")
                continue;
            if (!root.isGuiApp(entry))
                continue;
            if (root.isJunk(entry))
                continue;
            if (root.isFileManager(entry) && !root.isMainFileManager(entry))
                continue;
            const cid = String(root.canonicalAppId(entry.id) || "").toLowerCase();
            if (cid && seenId[cid])
                continue;
            if (cid)
                seenId[cid] = true;
            const steamId = root.steamAppId(entry);
            if (steamId) {
                if (seenSteam[steamId])
                    continue;
                seenSteam[steamId] = true;
            } else {
                const nameKey = String(entry.name).toLowerCase().replace(/[®™]/g, "").replace(/\s+/g, " ").trim();
                if (seenName[nameKey])
                    continue;
                seenName[nameKey] = true;
            }

            out.push(entry);
        }

        out.sort(function (a, b) {
            const an = a.name.toLowerCase();
            const bn = b.name.toLowerCase();

            if (an < bn)
                return -1;

            if (an > bn)
                return 1;

            return 0;
        });

        if (root.entries.length > 8 && out.length < Math.ceil(root.entries.length * 0.5))
            return;
        const cur = root.entries;
        if (cur.length === out.length) {
            let same = true;
            for (let i = 0; i < out.length; i++) {
                if (cur[i].id !== out[i].id) {
                    same = false;
                    break;
                }
            }
            if (same) {
                if (!root.launchpadOrder.length || !root.dockOrder.length)
                    root.syncLayout();
                return;
            }
        }

        root.entries = out;
        root.syncLayout();
    }

    readonly property int count: root.entries.length

    // Matching

    function subsequence(haystack, needle) {
        let h = 0;

        for (let n = 0; n < needle.length; n++) {
            let found = false;

            while (h < haystack.length) {
                if (haystack.charAt(h) === needle.charAt(n)) {
                    found = true;
                    h++;
                    break;
                }
                h++;
            }

            if (!found)
                return false;
        }

        return true;
    }

    // Tiers, strongest first.
    function score(entry, q) {
        const name = entry.name ? entry.name.toLowerCase() : "";

        if (name.indexOf(q) === 0)
            return 400;

        const words = name.split(/[\s\-_.]+/);
        for (let i = 0; i < words.length; i++) {
            if (words[i].indexOf(q) === 0)
                return 300;
        }

        if (name.indexOf(q) !== -1)
            return 200;

        const generic = entry.genericName ? entry.genericName.toLowerCase() : "";
        if (generic.length > 0 && generic.indexOf(q) !== -1)
            return 140;

        const comment = entry.comment ? entry.comment.toLowerCase() : "";
        if (comment.length > 0 && comment.indexOf(q) !== -1)
            return 100;

        const keywords = entry.keywords;
        if (keywords) {
            for (let k = 0; k < keywords.length; k++) {
                if (String(keywords[k]).toLowerCase().indexOf(q) !== -1)
                    return 100;
            }
        }

        if (root.subsequence(name, q))
            return 60;

        return -1;
    }

    function search(query) {
        const all = root.entries;

        if (!query || query.trim().length === 0) {
            const ranked = all.slice();
            ranked.sort(function (a, b) {
                const ua = root.usage[a.id] || 0;
                const ub = root.usage[b.id] || 0;
                if (ub !== ua)
                    return ub - ua;
                const an = String(a.name || "").toLowerCase();
                const bn = String(b.name || "").toLowerCase();
                if (an < bn)
                    return -1;
                if (an > bn)
                    return 1;
                return 0;
            });
            return ranked;
        }

        const q = query.trim().toLowerCase();
        const scored = [];

        for (let i = 0; i < all.length; i++) {
            const entry = all[i];
            let s = root.score(entry, q);

            if (s < 0)
                continue;

            // Frecency is a tie-breaker, capped so a heavily used app can never leapfrog a genuine prefix match.
            const hits = root.usage[entry.id] || 0;
            s += Math.min(50, hits * 6);

            scored.push({
                "entry": entry,
                "score": s,
                "index": i
            });
        }

        scored.sort(function (a, b) {
            if (b.score !== a.score)
                return b.score - a.score;

            return a.index - b.index;
        });

        const out = [];
        for (let j = 0; j < scored.length; j++)
            out.push(scored[j].entry);

        return out;
    }

    // Actions

    property var pendingLaunch: null
    property var pendingEntry: null
    property int pendingWorkspace: 0
    property bool launchConsumed: false
    property int existingGen: 0
    signal spawnStarting
    signal splashNeeded

    property Process existingProc: Process {
        property int gen: 0
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (exitCode) {
            if (existingProc.gen !== root.existingGen)
                return;
            root.onExistingDone(exitCode);
        }
    }

    property Timer existingWait: Timer {
        interval: 800
        repeat: false
        onTriggered: {
            if (existingProc.running) {
                existingProc.running = false;
                return;
            }
            root.onExistingDone(1);
        }
    }

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
        // Instant terminals — splash + activate-existing only add lag.
        if (root.isKitty(app) || text.indexOf("alacritty") !== -1 || text.indexOf("foot") !== -1 || text.indexOf("wezterm") !== -1 || text.indexOf("ghostty") !== -1)
            return true;
        // OBS needles used to match Obsidian and cancel the real spawn.
        if (root.isObs(app))
            return true;
        // Tray Activate "succeeds" and cancels the spawn; window never rises.
        if (root.isCursor(app))
            return true;
        return false;
    }

    function finishLaunch() {
        root.pendingLaunch = null;
        root.pendingEntry = null;
    }

    function spawnOut(cmd) {
        if (!cmd || !cmd.length)
            return;
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--"].concat(cmd));
    }

    function runDirect(app, entry) {
        const steamId = root.steamAppId(app);
        if (steamId) {
            root.spawnOut([root.home + "/.config/scripts/steam.sh", "steam://rungameid/" + steamId]);
            return;
        }
        if (root.isSpotify(app) || root.isSpotify(entry))
            root.spawnOut([root.home + "/.config/scripts/spotify"]);
        else if (root.isInsta360(app) || root.isInsta360(entry))
            root.spawnOut([root.home + "/.config/scripts/insta360-link.sh"]);
        else if (root.isObs(app) || root.isObs(entry))
            root.spawnOut([root.home + "/.config/scripts/obs.sh"]);
        else if (root.isCursor(app) || root.isCursor(entry))
            root.spawnOut([root.home + "/.config/scripts/cursor.sh"]);
        else if (root.isIdea(app) || root.isIdea(entry))
            root.spawnOut([root.home + "/.config/scripts/idea-ultimate.sh"]);
        else if (root.isDiscord(app) || root.isDiscord(entry))
            root.spawnOut([root.home + "/.config/scripts/discord.sh"]);
        else if (app.execute)
            app.execute();
        else if (app.command && app.command.length)
            root.spawnOut(app.command);
        else if (app.execString || app.exec)
            root.spawnOut(["sh", "-c", "exec " + root.stripFieldCodes(app.execString || app.exec)]);
    }

    function startExisting(app) {
        const needles = LaunchSplash.needlesOf(app);
        const cmd = [root.home + "/.config/scripts/activate-existing"];
        for (let i = 0; i < needles.length; i++)
            cmd.push(String(needles[i]));
        root.existingGen += 1;
        existingProc.gen = root.existingGen;
        if (existingProc.running)
            existingProc.running = false;
        existingProc.command = cmd;
        existingProc.running = true;
        existingWait.restart();
    }

    function onExistingDone(code) {
        existingWait.stop();
        const app = root.pendingLaunch;
        const entry = root.pendingEntry;
        const ws = root.pendingWorkspace;
        if (!app)
            return;
        if (root.launchConsumed) {
            root.finishLaunch();
            return;
        }
        if (code === 0) {
            root.launchConsumed = true;
            root.finishLaunch();
            return;
        }
        if (code === 2) {
            // Process lives but tray did not raise — focus the mapped window
            // instead of spawning a second client + LaunchSplash skeleton.
            if (LaunchSplash.tryFocus(app)) {
                root.launchConsumed = true;
                root.finishLaunch();
                return;
            }
            root.execPinned(app, entry, ws);
            root.finishLaunch();
            return;
        }
        // Last chance before splash: Quickshell toplevels may lag; try again.
        if (LaunchSplash.tryFocus(app)) {
            root.launchConsumed = true;
            root.finishLaunch();
            return;
        }
        root.splashNeeded();
        if (root.launchConsumed) {
            root.finishLaunch();
            return;
        }
        if (root.skipSplash(app))
            root.runDirect(app, entry);
        else
            root.execPinned(app, entry, ws);
        root.finishLaunch();
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
        root.pendingEntry = entry;
        root.pendingWorkspace = Core.Session.activeWorkspaceOnMonitor(Core.Session.focusedMonitorName());
        root.launchConsumed = false;
        // Already mapped → focus only. Tray Activate used to swallow the
        // click and leave Cursor/OBS sitting in the background.
        if (LaunchSplash.tryFocus(app)) {
            root.finishLaunch();
            return;
        }
        if (root.isObs(app) || root.isObs(entry) || root.isCursor(app) || root.isCursor(entry) || root.isIdea(app) || root.isIdea(entry)) {
            LaunchSplash.armLaunch(app, root.pendingWorkspace);
            root.runDirect(app, entry);
            root.finishLaunch();
            return;
        }
        root.spawnStarting();
        if (root.launchConsumed) {
            root.finishLaunch();
            return;
        }
        if (root.skipSplash(app)) {
            root.runDirect(app, entry);
            root.finishLaunch();
            return;
        }
        root.startExisting(app);
    }

    function luaQuote(s) {
        return "\"" + String(s || "").replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\"";
    }

    function shellJoin(args) {
        const out = [];
        for (let i = 0; i < args.length; i++)
            out.push("'" + String(args[i]).replace(/'/g, "'\\''") + "'");
        return out.join(" ");
    }

    function stripFieldCodes(line) {
        return String(line || "").replace(/%[fFuUdDnNickvm]/g, "").replace(/\s+/g, " ").trim();
    }

    function execPinned(app, entry, ws) {
        const id = Number(ws);
        const rule = id >= 1 ? "[workspace " + id + " silent] " : "";
        let cmd = "";
        if (root.isSpotify(app) || root.isSpotify(entry))
            cmd = "'" + root.home + "/.config/scripts/spotify'";
        else if (root.isInsta360(app) || root.isInsta360(entry))
            cmd = "'" + root.home + "/.config/scripts/insta360-link.sh'";
        else if (root.isObs(app) || root.isObs(entry))
            cmd = "'" + root.home + "/.config/scripts/obs.sh'";
        else if (root.isCursor(app) || root.isCursor(entry))
            cmd = "'" + root.home + "/.config/scripts/cursor.sh'";
        else if (root.isIdea(app) || root.isIdea(entry))
            cmd = "'" + root.home + "/.config/scripts/idea-ultimate.sh'";
        else if (root.isDiscord(app) || root.isDiscord(entry))
            cmd = "'" + root.home + "/.config/scripts/discord.sh'";
        else if (root.steamAppId(app) || root.steamAppId(entry))
            cmd = "'" + root.home + "/.config/scripts/steam.sh' 'steam://rungameid/" + (root.steamAppId(app) || root.steamAppId(entry)) + "'";
        else if (app.command && app.command.length)
            cmd = root.shellJoin(app.command);
        else if (app.execString || app.exec) {
            // Hypr exec_cmd is not a shell — bare `obs` / PATH binaries die when
            // the dispatcher PATH is thin. Always run desktop Exec via sh.
            const inner = root.stripFieldCodes(app.execString || app.exec);
            cmd = "sh -c " + "'" + String(inner).replace(/'/g, "'\\''") + "'";
        }
        if (!cmd) {
            if (app.execute)
                app.execute();
            return;
        }
        Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.exec_cmd(" + root.luaQuote(rule + cmd) + "))"]);
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

    function classAliases(cls) {
        const c = String(cls || "").toLowerCase().trim().replace(/\.desktop$/, "");
        if (!c)
            return [];
        if (c.indexOf("org.telegram.desktop") === 0)
            return ["org.telegram.desktop", "telegram-1", "telegram-2", "telegram"];
        if (c === "chrome-az" || c.indexOf("chrome-az") === 0)
            return ["chrome-az"];
        if (c === "chrome-hika" || c.indexOf("chrome-hika") === 0)
            return ["chrome-hika"];
        if (c === "chrome-sciencesoft" || c.indexOf("chrome-sciencesoft") === 0)
            return ["chrome-sciencesoft"];
        if (c === "chrome-dd" || c === "google-chrome" || c === "com.google.chrome" || c.indexOf("chrome-dd") === 0)
            return ["chrome-dd", "google-chrome", "com.google.chrome"];
        if (c === "steam_app_761890" || c.indexOf("albion") !== -1)
            return ["albion-online", "albion online", "steam_app_761890", "albion"];
        if (c === "md.obsidian" || c === "obsidian")
            return ["obsidian", "md.obsidian"];
        if (c === "openlens" || c === "open-lens")
            return ["openlens", "open-lens"];
        if (c === "jetbrains-idea" || c === "idea-ultimate" || c === "idea")
            return ["jetbrains-idea", "idea-ultimate", "idea"];
        if (c.indexOf("libreoffice") === 0)
            return ["libreoffice-startcenter", "libreoffice", c];
        return [c];
    }

    function entryNeedles(entry) {
        if (!entry)
            return [];
        const id = String(entry.id || "").toLowerCase().replace(/\.desktop$/, "");
        const start = String(entry.startupWmClass || entry.startupClass || entry.wmClass || "").toLowerCase();
        const out = [];
        if (id)
            out.push(id);
        if (start)
            out.push(start);
        const extra = root.classAliases(start || id);
        for (let i = 0; i < extra.length; i++) {
            if (out.indexOf(extra[i]) === -1)
                out.push(extra[i]);
        }
        return out;
    }

    function classMatchesEntry(cls, entry) {
        const aliases = root.classAliases(cls);
        const needles = root.entryNeedles(entry);
        for (let i = 0; i < aliases.length; i++) {
            const a = aliases[i];
            for (let j = 0; j < needles.length; j++) {
                const n = needles[j];
                if (!a || !n)
                    continue;
                // Exact alias match only. Short needles like "idea" must not
                // substring-match unrelated classes/titles.
                if (a === n)
                    return true;
                // Allow org.foo.bar ↔ org.foo desktop-id style prefixes.
                if (n.length >= 6 && (a.indexOf(n + ".") === 0 || n.indexOf(a + ".") === 0))
                    return true;
            }
        }
        return false;
    }

    function entryIsRunning(entry, classes) {
        const list = classes || [];
        for (let i = 0; i < list.length; i++) {
            if (root.classMatchesEntry(list[i], entry))
                return true;
        }
        return false;
    }

    function entryForClass(cls) {
        const needle = String(cls || "").toLowerCase().trim();
        if (!needle)
            return null;
        if (needle.indexOf("gamescope") !== -1)
            return null;

        const aliases = root.classAliases(needle);
        const entries = root.entries;
        let best = null;
        let bestScore = 0;

        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (!e)
                continue;
            if (root.classMatchesEntry(needle, e)) {
                const start = String(e.startupWmClass || e.startupClass || e.wmClass || "").toLowerCase();
                const id = String(e.id || "").toLowerCase().replace(/\.desktop$/, "");
                let score = 70;
                if (aliases.indexOf(start) !== -1)
                    score = 100;
                else if (aliases.indexOf(id) !== -1)
                    score = 90;
                if (score > bestScore) {
                    bestScore = score;
                    best = e;
                }
                continue;
            }
            const id = String(e.id || "").toLowerCase();
            const start = String(e.startupWmClass || e.startupClass || e.wmClass || "").toLowerCase();
            const icon = String(e.icon || "").toLowerCase();
            const name = String(e.name || "").toLowerCase().replace(/\s+/g, "");
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

    function iconForContainer(name) {
        const raw = String(name || "").toLowerCase();
        if (!raw)
            return root.resolveIcon("", "application-x-executable");
        const aliases = {
            "chrome-dd": "google-chrome",
            "chrome-az": "chrome-az",
            "chrome-hika": "chrome-hika",
            "chrome-sciencesoft": "chrome-sciencesoft",
            "vscode": "code",
            "idea": "idea-ultimate",
            "libreoffice": "libreoffice-startcenter",
            "telegram-1": "telegram-1",
            "telegram-2": "telegram-2"
        };
        const id = aliases[raw] || raw.replace(/-\d+$/, "");
        const entry = root.entryForClass(id) || root.entryForClass(raw);
        if (entry)
            return root.iconSource(entry);
        return root.resolveIcon(id, "application-x-executable");
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
        if (root.isObsidian(entry))
            return root.obsidianIcon;
        if (root.isChrome(entry))
            return root.chromeIcon;
        if (root.isKitty(entry))
            return root.kittyIcon;
        if (root.isAmnezia(entry))
            return root.amneziaIcon;
        if (entry.icon)
            return root.resolveIcon(entry.icon, "application-x-executable");
        return root.resolveIcon(entry.id || entry.name || "", "application-x-executable");
    }

    function iconPathForClass(cls, title) {
        const clsStr = String(cls || "");
        const titleStr = String(title || "");
        const needle = clsStr.toLowerCase();
        if (needle.indexOf("obsidian") !== -1 || titleStr.toLowerCase().indexOf("obsidian") !== -1)
            return root.obsidianIcon;
        if (needle.indexOf("chrome") !== -1 || titleStr.toLowerCase().indexOf("chrome") !== -1)
            return root.chromeIcon;
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
        root.loadUsage();
        root.loadLayout();
        root.rebuildEntries();
    }
}
