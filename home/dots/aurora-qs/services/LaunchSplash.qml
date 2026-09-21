pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

import "../core" as Core

// Placeholder window (frontend Suspense) until the real client paints.
QtObject {
    id: root

    property bool active: false
    property bool shown: false
    property int gen: 0
    property string monitorName: ""
    property string appName: ""
    property string icon: ""
    property string kind: "app"
    property var needles: []
    property var ignore: ({})
    property var matched: null
    property bool painted: false
    property string lastGeom: ""
    property int stableTicks: 0
    property int mappedAt: 0
    property int shownAt: 0

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
            if (AppsService.skipSplash(app))
                return;
            root.begin({
                "name": AppsService.displayName(app),
                "icon": AppsService.iconSource(app),
                "kind": AppsService.splashKind(app),
                "needles": root.needlesOf(app)
            });
        }
    }

    function begin(dto) {
        if (!dto)
            return;
        root.clear();
        root.gen += 1;
        root.appName = String(dto.name || "App");
        root.icon = String(dto.icon || "");
        root.kind = String(dto.kind || "app");
        root.needles = dto.needles || [];
        root.monitorName = Core.Session.focusedMonitorName();
        root.ignore = root.snapshotAddresses();
        root.matched = null;
        root.painted = false;
        root.lastGeom = "";
        root.stableTicks = 0;
        root.mappedAt = 0;
        root.shownAt = 0;
        root.active = true;
        root.shown = false;
        showDelay.restart();
        poll.restart();
        failSafe.restart();
    }

    function tryFocus(app) {
        const t = root.findToplevel(root.needlesOf(app), null);
        if (!t)
            return false;
        Core.Session.focusWindow(t);
        return true;
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
        root.ignore = ({});
        root.lastGeom = "";
        root.stableTicks = 0;
        root.mappedAt = 0;
        root.shownAt = 0;
    }

    function needlesOf(app) {
        const out = [];
        const seen = ({});
        function add(v) {
            const s = String(v || "").toLowerCase().trim();
            if (!s || s.length < 2 || seen[s])
                return;
            seen[s] = true;
            out.push(s);
        }
        if (!app)
            return out;
        add(app.startupWmClass || app.startupClass || app.wmClass);
        add(app.id);
        add(String(app.id || "").split(".").pop());
        const name = String(app.name || "").toLowerCase();
        const exec = String(app.execString || app.exec || "").toLowerCase();
        const blob = name + " " + exec;
        if (blob.indexOf("firefox") !== -1)
            add("firefox");
        if (blob.indexOf("chrome") !== -1) {
            add("google-chrome");
            add("chrome");
        }
        if (blob.indexOf("zen") !== -1) {
            add("zen");
            add("zen-browser");
        }
        if (blob.indexOf("spotify") !== -1)
            add("spotify");
        if (blob.indexOf("cursor") !== -1)
            add("cursor");
        if (blob.indexOf("code") !== -1 && blob.indexOf("cursor") === -1)
            add("code");
        if (blob.indexOf("kitty") !== -1)
            add("kitty");
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

    function findToplevel(needles, ignoreMap) {
        const list = needles || [];
        if (!list.length)
            return null;
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        let best = null;
        let bestArea = -1;
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const addr = root.addressOf(t);
            if (ignoreMap && addr && ignoreMap[addr])
                continue;
            const ipc = t.lastIpcObject || {};
            if (ipc.hidden === true)
                continue;
            const cls = root.classOf(t);
            if (!cls || cls.indexOf("quickshell") !== -1 || cls.indexOf("aurora-") !== -1)
                continue;
            const title = String(t.title || ipc.title || "").toLowerCase();
            let hit = false;
            for (let n = 0; n < list.length; n++) {
                const needle = list[n];
                if (!needle)
                    continue;
                if (cls === needle || cls.indexOf(needle) !== -1 || (needle.length >= 4 && needle.indexOf(cls) !== -1)) {
                    hit = true;
                    break;
                }
                if (title.indexOf(needle) !== -1) {
                    hit = true;
                    break;
                }
            }
            if (!hit)
                continue;
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

    function tick() {
        if (!root.active)
            return;
        const t = root.findToplevel(root.needles, root.ignore);
        if (t && t !== root.matched) {
            root.matched = t;
            if (!root.mappedAt)
                root.mappedAt = Date.now();
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
        if (root.stableTicks >= 5) {
            root.finish();
            return;
        }
        if (sinceMap >= 1100)
            root.finish();
    }

    property Timer showDelay: Timer {
        interval: 90
        repeat: false
        onTriggered: {
            if (!root.active)
                return;
            if (root.matched) {
                root.clear();
                return;
            }
            root.shown = true;
            root.shownAt = Date.now();
        }
    }

    property Timer poll: Timer {
        interval: 50
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
