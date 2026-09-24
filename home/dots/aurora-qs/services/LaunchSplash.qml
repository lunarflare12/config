pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray

import "../core" as Core

// Placeholder window (frontend Suspense) until the real client paints.
Singleton {
    id: root

    property bool active: false
    property bool shown: false
    property int gen: 0
    property string monitorName: ""
    property string appName: ""
    property string icon: ""
    property string kind: "app"
    property var needles: []
    property var launchApp: null
    property var ignore: ({})
    property var matched: null
    property bool painted: false
    property string lastGeom: ""
    property int stableTicks: 0
    property int mappedAt: 0
    property int shownAt: 0
    property int workspaceId: 0
    property bool pinned: false
    property int lastPinAt: 0

    readonly property string pinPath: Quickshell.env("HOME") + "/.local/state/aurora-launch"

    property FileView pinFile: FileView {
        path: root.pinPath
        blockLoading: false
        printErrors: false
    }

    readonly property var handle: {
        const t = root.matched;
        return (t && t.wayland) ? t.wayland : null;
    }

    readonly property int toplevelCount: (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0

    onToplevelCountChanged: {
        if (root.active)
            root.tick();
    }

    property var overviewWatch: Core.Session.overviewOpen
    onOverviewWatchChanged: {
        if (root.overviewWatch && root.active)
            root.finish();
    }

    property Connections spawnHook: Connections {
        target: AppsService
        function onSpawnStarting() {
            const app = AppsService.pendingLaunch;
            if (!app)
                return;
            if (root.tryFocus(app)) {
                AppsService.launchConsumed = true;
                return;
            }
        }

        function onSplashNeeded() {
            const app = AppsService.pendingLaunch;
            if (!app || AppsService.skipSplash(app))
                return;
            if (root.tryFocus(app)) {
                AppsService.launchConsumed = true;
                return;
            }
            root.begin({
                "name": AppsService.displayName(app),
                "icon": AppsService.iconSource(app),
                "kind": AppsService.splashKind(app),
                "needles": root.needlesOf(app),
                "app": app
            });
        }
    }

    function launchWorkspace() {
        const ws = Number(AppsService.pendingWorkspace);
        if (ws >= 1)
            return ws;
        return Core.Session.activeWorkspaceOnMonitor(Core.Session.focusedMonitorName());
    }

    function armLaunch(app, ws) {
        root.launchApp = app;
        root.needles = root.needlesOf(app);
        root.workspaceId = Number(ws) >= 1 ? Number(ws) : root.launchWorkspace();
        root.writePin();
        return root.workspaceId;
    }

    function begin(dto) {
        if (!dto)
            return;
        const app = dto.app || AppsService.pendingLaunch;
        const dest = root.launchWorkspace();
        // Already-open window → focus only. Never show the skeleton preview.
        const running = root.findRunning(app);
        if (running) {
            Core.Session.bringWindow(running, dest);
            AppsService.launchConsumed = true;
            root.clear();
            return;
        }
        root.clear();
        root.gen += 1;
        root.appName = String(dto.name || "App");
        root.icon = String(dto.icon || "");
        root.kind = String(dto.kind || "app");
        root.needles = dto.needles || root.needlesOf(app);
        root.launchApp = app;
        root.monitorName = Core.Session.focusedMonitorName();
        root.workspaceId = dest;
        if (!(root.workspaceId >= 1))
            root.workspaceId = Core.Session.activeWorkspaceOnMonitor(root.monitorName);
        root.ignore = root.snapshotAddresses();
        // Re-check after snapshot: if a matching client was already mapped,
        // it is in ignore — still focus it and abort splash.
        const existing = root.findWindow(app, root.needles, null, true);
        if (existing) {
            Core.Session.bringWindow(existing, dest);
            AppsService.launchConsumed = true;
            root.clear();
            return;
        }
        root.matched = null;
        root.painted = false;
        root.pinned = false;
        root.lastGeom = "";
        root.stableTicks = 0;
        root.mappedAt = 0;
        root.shownAt = 0;
        root.active = true;
        root.shown = false;
        root.writePin();
        showDelay.restart();
        poll.restart();
        failSafe.restart();
    }

    function tryFocus(app) {
        const t = root.findRunning(app);
        if (!t)
            return false;
        Core.Session.bringWindow(t, root.launchWorkspace());
        return true;
    }

    function trayBlob(item) {
        if (!item)
            return "";
        return String((item.id || "") + " " + (item.title || "") + " " + (item.tooltip || "") + " " + (item.icon || "")).toLowerCase();
    }

    function trayItems() {
        const model = SystemTray.items;
        if (!model)
            return [];
        if (model.values)
            return model.values;
        const out = [];
        const n = Number(model.count || 0);
        for (let i = 0; i < n; i++) {
            const it = model.get ? model.get(i) : model[i];
            if (it)
                out.push(it);
        }
        return out;
    }

    function activateTray(app) {
        if (!app || AppsService.steamAppId(app))
            return false;
        const items = root.trayItems();
        if (!items.length)
            return false;
        const needles = root.needlesOf(app);
        for (let i = 0; i < items.length; i++) {
            const it = items[i];
            const hay = root.trayBlob(it);
            if (!hay)
                continue;
            if (hay.indexOf("chrome_status_icon") >= 0 && hay.indexOf("discord") < 0)
                continue;
            for (let n = 0; n < needles.length; n++) {
                const needle = String(needles[n] || "").toLowerCase();
                if (!needle || needle.length < 4 || root.isGenericToken(needle))
                    continue;
                if (needle === "chrome" || needle === "chromium")
                    continue;
                if (hay.indexOf(needle) < 0)
                    continue;
                if (typeof it.activate !== "function")
                    continue;
                it.activate();
                return true;
            }
        }
        return false;
    }

    function markPainted() {
        if (!root.active)
            return;
        root.painted = true;
        root.tick();
    }

    function finish() {
        if (!root.active)
            return;
        if (!root.shown) {
            root.clear();
            return;
        }
        root.shown = false;
        hideWait.restart();
    }

    function release() {
        if (!root.shown)
            root.clear();
    }

    function clear() {
        showDelay.stop();
        poll.stop();
        failSafe.stop();
        hideWait.stop();
        root.active = false;
        root.shown = false;
        root.matched = null;
        root.painted = false;
        root.needles = [];
        root.launchApp = null;
        root.ignore = ({});
        root.lastGeom = "";
        root.stableTicks = 0;
        root.mappedAt = 0;
        root.shownAt = 0;
        root.workspaceId = 0;
        root.pinned = false;
        root.lastPinAt = 0;
        root.clearPin();
    }

    function writePin() {
        const ws = Number(root.workspaceId) || 0;
        const needles = (root.needles || []).join(",");
        if (!(ws >= 1) || !needles)
            return;
        root.pinFile.setText(ws + " " + needles + "\n");
    }

    function clearPin() {
        root.pinFile.setText("");
    }

    function pinMatched() {
        if (!root.matched || !(root.workspaceId >= 1))
            return;
        const addr = root.addressOf(root.matched);
        if (addr && root.ignore[addr])
            return;
        const at = Core.Session.toplevelWorkspaceId(root.matched);
        if (at === root.workspaceId) {
            root.pinned = true;
            return;
        }
        const now = Date.now();
        if (root.lastPinAt && now - root.lastPinAt < 140)
            return;
        root.lastPinAt = now;
        Core.Session.moveWindowSilent(root.matched, root.workspaceId);
    }

    function isGenericToken(s) {
        const n = String(s || "");
        if (!n || n.length < 3)
            return true;
        const homeUser = String(Quickshell.env("HOME") || "").split("/").pop().toLowerCase();
        if (homeUser && n === homeUser)
            return true;
        return n === "desktop" || n === "org" || n === "com" || n === "io" || n === "net" || n === "app" || n === "www" || n === "gtk" || n === "gnome" || n === "kde" || n === "qt" || n === "bin" || n === "usr" || n === "status" || n === "icon" || n === "tray" || n === "item" || n === "force" || n === "dark" || n === "mode" || n === "wayland" || n === "ozone" || n === "platform" || n === "disable" || n === "enable" || n === "gpu" || n === "features" || n === "sandbox" || n === "scripts" || n === "config" || n === "home" || n === "nix" || n === "store";
    }

    function execBase(app) {
        const steamId = AppsService.steamAppId(app);
        if (steamId)
            return "steam_app_" + steamId;
        let line = "";
        if (app && app.command && app.command.length)
            line = String(app.command[0] || "");
        if (!line)
            line = String(app && (app.execString || app.exec) || "");
        line = line.trim();
        if (!line)
            return "";
        const parts = line.split(/\s+/);
        let bin = parts[0] || "";
        if (bin === "env" || bin.endsWith("/env")) {
            for (let i = 1; i < parts.length; i++) {
                if (parts[i].indexOf("=") >= 0)
                    continue;
                bin = parts[i];
                break;
            }
        }
        bin = bin.split("/").pop().toLowerCase();
        return bin.replace(/\.(desktop|sh)$/, "");
    }

    function clsHits(cls, needle) {
        const c = String(cls || "").toLowerCase();
        const n = String(needle || "").toLowerCase().replace(/\.desktop$/, "");
        if (!c || !n || n.length < 3 || root.isGenericToken(n))
            return false;
        if (c === n)
            return true;
        // Substring only on token boundaries — bare "obs" must not match "obsidian".
        function bounded(hay, needle) {
            let from = 0;
            while (from <= hay.length) {
                const idx = hay.indexOf(needle, from);
                if (idx < 0)
                    return false;
                const before = idx > 0 ? hay.charAt(idx - 1) : "";
                const after = hay.charAt(idx + needle.length);
                const edgeL = !before || !/[a-z0-9]/.test(before);
                const edgeR = !after || !/[a-z0-9]/.test(after);
                if (edgeL && edgeR)
                    return true;
                from = idx + 1;
            }
            return false;
        }
        if (bounded(c, n))
            return true;
        if (n.length >= 4 && c.length >= 4 && bounded(n, c))
            return true;
        const cLast = c.split(/[-._]/).pop();
        const nLast = n.split(/[-._]/).pop();
        if (cLast.length >= 4 && nLast.length >= 4 && cLast === nLast)
            return true;
        return false;
    }

    function windowHits(t, app, needles, allowHidden) {
        if (!t)
            return false;
        const ipc = t.lastIpcObject || {};
        if (!allowHidden && ipc.hidden === true)
            return false;
        const cls = root.classOf(t);
        if (!cls || cls.indexOf("quickshell") !== -1 || cls.indexOf("aurora-") !== -1)
            return false;
        const title = String(t.title || ipc.title || "").toLowerCase();
        const steamId = AppsService.steamAppId(app);
        if (steamId) {
            const want = "steam_app_" + steamId;
            if (cls === want || cls.indexOf(want) === 0)
                return true;
            const name = String(app && app.name || "").toLowerCase().replace(/®/g, "").trim();
            if (name.length >= 4 && cls !== "steam" && title.indexOf(name) >= 0)
                return true;
            return false;
        }
        if (app) {
            const start = String(app.startupWmClass || app.startupClass || app.wmClass || "").toLowerCase();
            const id = String(app.id || "").toLowerCase().replace(/\.desktop$/, "");
            const idBase = id.split(".").pop();
            const name = String(app.name || "").toLowerCase();
            const exec = root.execBase(app);
            if (start && root.clsHits(cls, start))
                return true;
            if (id && root.clsHits(cls, id))
                return true;
            if (idBase && !root.isGenericToken(idBase) && root.clsHits(cls, idBase))
                return true;
            if (exec && root.clsHits(cls, exec))
                return true;
            const nameKey = name.replace(/\s+/g, "");
            if (nameKey.length >= 4 && (cls.indexOf(nameKey) >= 0 || title.indexOf(name) >= 0))
                return true;
            const mapped = AppsService.entryForClass(cls);
            if (mapped && app.id && mapped.id && String(mapped.id) === String(app.id))
                return true;
        }
        const list = needles || [];
        for (let n = 0; n < list.length; n++) {
            const needle = list[n];
            if (!needle || root.isGenericToken(needle))
                continue;
            if (root.clsHits(cls, needle))
                return true;
            if (needle.length >= 5 && title.indexOf(needle) >= 0)
                return true;
        }
        return false;
    }

    function findRunning(app) {
        return root.findWindow(app, root.needlesOf(app), null, true);
    }

    function findWindow(app, needles, ignoreMap, allowHidden) {
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        let best = null;
        let bestArea = -1;
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const addr = root.addressOf(t);
            if (ignoreMap && addr && ignoreMap[addr])
                continue;
            if (!root.windowHits(t, app, needles, allowHidden))
                continue;
            const ipc = t.lastIpcObject || {};
            const size = ipc.size || [];
            const area = Number(size[0] || t.width || 0) * Number(size[1] || t.height || 0);
            if (area < 40000 && bestArea >= 40000)
                continue;
            if (area >= bestArea) {
                best = t;
                bestArea = area;
            }
        }
        return best;
    }

    function needlesOf(app) {
        const out = [];
        const seen = ({});
        function add(v) {
            let s = String(v || "").toLowerCase().trim().replace(/\.desktop$/, "");
            if (!s || s.length < 2 || seen[s] || root.isGenericToken(s))
                return;
            seen[s] = true;
            out.push(s);
        }
        if (!app)
            return out;
        add(app.startupWmClass || app.startupClass || app.wmClass);
        add(app.id);
        add(String(app.id || "").split(".").pop());
        add(root.execBase(app));
        const steamId = AppsService.steamAppId(app);
        if (steamId)
            add("steam_app_" + steamId);
        const name = String(app.name || "").toLowerCase();
        const icon = String(app.icon || "").toLowerCase().split("/").pop();
        const blob = name + " " + icon + " " + String(app.id || "").toLowerCase();
        const parts = blob.split(/[^a-z0-9]+/);
        for (let i = 0; i < parts.length; i++)
            add(parts[i]);
        if (name)
            add(name.replace(/\s+/g, ""));
        return out;
    }

    function snapshotAddresses() {
        const map = ({});
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const addr = root.addressOf(tops[i]);
            if (addr)
                map[addr] = true;
        }
        return map;
    }

    function addressOf(t) {
        if (!t)
            return "";
        const ipc = t.lastIpcObject || {};
        let addr = String(ipc.address || t.address || "");
        if (!addr)
            return "";
        if (addr.indexOf("0x") !== 0 && addr.indexOf("0X") !== 0)
            addr = "0x" + addr;
        return addr.toLowerCase();
    }

    function classOf(t) {
        const ipc = t && t.lastIpcObject ? t.lastIpcObject : {};
        return String(ipc.class || ipc.initialClass || ipc.initial_class || (t && t.class) || "").toLowerCase();
    }

    function geomOf(t) {
        const ipc = t && t.lastIpcObject ? t.lastIpcObject : {};
        const at = ipc.at || [];
        const size = ipc.size || [];
        return String(at[0] || 0) + "," + String(at[1] || 0) + "," + String(size[0] || t.width || 0) + "x" + String(size[1] || t.height || 0);
    }

    function tick() {
        if (!root.active)
            return;
        const already = root.findWindow(root.launchApp, root.needles, null);
        if (already && root.ignore[root.addressOf(already)]) {
            Core.Session.bringWindow(already, root.workspaceId || root.launchWorkspace());
            root.clear();
            return;
        }
        const t = root.findWindow(root.launchApp, root.needles, root.ignore);
        if (t && t !== root.matched) {
            root.matched = t;
            root.pinned = false;
            root.lastPinAt = 0;
            if (!root.mappedAt)
                root.mappedAt = Date.now();
            root.pinMatched();
        } else if (root.matched) {
            root.pinMatched();
        }
        if (!root.matched)
            return;
        const geom = root.geomOf(root.matched);
        if (geom === root.lastGeom)
            root.stableTicks += 1;
        else {
            root.lastGeom = geom;
            root.stableTicks = 0;
        }
        if (!root.shown) {
            root.finish();
            return;
        }
        const now = Date.now();
        const sinceMap = root.mappedAt ? now - root.mappedAt : 0;
        const sinceShown = root.shownAt ? now - root.shownAt : 0;
        if (sinceShown < 180)
            return;
        if (root.painted && root.stableTicks >= 2) {
            root.finish();
            return;
        }
        if (root.stableTicks >= 2) {
            root.finish();
            return;
        }
        if (sinceMap >= 280)
            root.finish();
    }

    property Timer showDelay: Timer {
        // Fast apps map in <50ms; keep this low so skeleton rarely flashes.
        interval: 140
        repeat: false
        onTriggered: {
            if (!root.active)
                return;
            // Any matching mapped window (including ones present at arm time)
            // means the app was already open — focus it, never show skeleton.
            const already = root.findWindow(root.launchApp, root.needles, null, true);
            if (already) {
                Core.Session.bringWindow(already, root.workspaceId || root.launchWorkspace());
                AppsService.launchConsumed = true;
                root.clear();
                return;
            }
            // Still nothing after the grace window — only then show skeleton.
            root.shown = true;
            root.shownAt = Date.now();
        }
    }

    property Timer poll: Timer {
        interval: 32
        repeat: true
        onTriggered: root.tick()
    }

    property Timer failSafe: Timer {
        interval: 7000
        repeat: false
        onTriggered: root.finish()
    }

    property Timer hideWait: Timer {
        interval: 240
        repeat: false
        onTriggered: root.release()
    }
}
