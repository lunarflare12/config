pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: root

    property bool overviewOpen: false
    property bool screenshotOpen: false
    property bool previewOpen: false
    property string previewPath: ""
    property var previewPaths: []
    property int previewIndex: 0
    property bool desktopEdit: false
    property int desktopMetricsCount: 0
    readonly property bool showDesktopMetrics: root.desktopMetricsCount > 0
    property bool overviewDrag: false
    property string overviewDragKind: ""
    property var overviewDragToplevel: null
    property string overviewDragFromMonitor: ""
    property int overviewDragFromLocal: 0
    property real overviewDragX: 0
    property real overviewDragY: 0
    property string overviewDropMonitor: ""
    property int overviewDropLocal: 0
    property var overviewDropSwap: null
    property bool overviewDropPlus: false
    property int overviewDropIndex: 0
    property var spaceOrder: ({})
    property int spaceRev: 0
    property bool compacting: false

    property Timer packTimer: Timer {
        interval: 180
        repeat: false
        onTriggered: {}
    }

    property Timer packUnlock: Timer {
        interval: 500
        repeat: false
        onTriggered: root.compacting = false
    }

    property Process cursorProc: Process {
        running: root.overviewDrag
        command: ["bash", "-lc", "while true; do hyprctl cursorpos; sleep 0.016; done"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                const m = String(line).match(/(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)/);
                if (!m || !root.overviewDrag)
                    return;
                root.overviewDragX = Number(m[1]);
                root.overviewDragY = Number(m[2]);
            }
        }
    }

    readonly property int packWatch: {
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values.length : 0;
        const spaces = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values.length : 0;
        return tops * 1009 + spaces * 17;
    }

    onPackWatchChanged: {
    }

    readonly property string scripts: Quickshell.env("HOME") + "/.config/scripts"
    readonly property int workspacesPerMonitor: 6
    readonly property var monitorOrder: ["DP-1", "HDMI-A-1"]
    property bool forceHideGameBar: false
    property bool activeWindowFullscreen: false
    property bool activeWindowCovers: false
    property string activeWindowMonitor: ""
    property string activeWindowClass: ""
    property string activeWindowTitle: ""
    property var openClasses: []
    property var openClients: []
    property int clientsTick: 0
    property int fsTick: 0

    property Process fsPoll: Process {
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text)
                    return;
                try {
                    const o = JSON.parse(text);
                    if (!o || o.class === undefined) {
                        root.activeWindowFullscreen = false;
                        root.activeWindowCovers = false;
                        root.activeWindowClass = "";
                        root.activeWindowTitle = "";
                        if (root.sattyOpen && !root.sattyDismissed && Date.now() >= root.sattySuppressUntil)
                            root.dismissScreenshot();
                        return;
                    }
                    root.activeWindowClass = String(o.class || o.initialClass || "");
                    root.activeWindowTitle = String(o.title || "");
                    const fs = Number(o.fullscreen || 0);
                    const fsc = Number(o.fullscreenClient || 0);
                    const cls = String(o.class || o.initialClass || "").toLowerCase();
                    if (root.sattyOpen && !root.sattyDismissed && Date.now() >= root.sattySuppressUntil && cls.indexOf("satty") === -1)
                        root.dismissScreenshot();
                    const exclusive = fs >= 2 || fsc >= 2;
                    const game = cls.indexOf("steam_app_") !== -1 || cls.indexOf("gamescope") !== -1 || cls.indexOf("dota2") !== -1 || cls.indexOf("minecraft") !== -1 || cls.indexOf("albion") !== -1;
                    const media = cls.indexOf("google-chrome") !== -1 || cls === "chrome" || cls.indexOf("firefox") !== -1 || cls.indexOf("zen") !== -1 || cls === "mpv" || cls.indexOf("vlc") !== -1 || cls.indexOf("celluloid") !== -1;
                    root.activeWindowFullscreen = exclusive || (media && (fs >= 1 || fsc >= 1));
                    const at = o.at || [0, 0];
                    const size = o.size || [0, 0];
                    let covers = false;
                    let monName = "";
                    const mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [];
                    for (let i = 0; i < mons.length; i++) {
                        const m = mons[i];
                        const mx = Number(m.x || 0);
                        const my = Number(m.y || 0);
                        const mw = Number(m.width || 0);
                        const mh = Number(m.height || 0);
                        if (Math.abs(Number(at[0]) - mx) <= 8 && Math.abs(Number(at[1]) - my) <= 8 && Number(size[0]) >= mw - 16 && Number(size[1]) >= mh - 16) {
                            covers = true;
                            monName = m.name || "";
                            break;
                        }
                    }
                    if (!monName) {
                        for (let j = 0; j < mons.length; j++) {
                            if (Number(mons[j].id) === Number(o.monitor)) {
                                monName = mons[j].name || "";
                                break;
                            }
                        }
                    }
                    root.activeWindowCovers = covers;
                    root.activeWindowMonitor = monName;
                    root.fsTick += 1;
                } catch (e) {}
            }
        }
    }

    property Timer fsTimer: Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            if (root.fsPoll.running)
                root.fsPoll.running = false;
            root.fsPoll.running = true;
        }
    }

    property Process clientsPoll: Process {
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text)
                    return;
                try {
                    const data = JSON.parse(text);
                    if (!Array.isArray(data))
                        return;
                    const classes = [];
                    const clients = [];
                    const seen = {};
                    for (let i = 0; i < data.length; i++) {
                        const row = data[i];
                        const c = String(row.class || row.initialClass || "").toLowerCase();
                        if (!c || c.indexOf("quickshell") >= 0 || c.indexOf("aurora-") >= 0)
                            continue;
                        const ws = row.workspace && typeof row.workspace === "object" ? Number(row.workspace.id) : Number(row.workspace);
                        const at = row.at || [0, 0];
                    const size = row.size || [0, 0];
                    clients.push({
                            "class": c,
                            "title": String(row.title || ""),
                            "workspace": ws,
                            "address": String(row.address || ""),
                            "x": Number(at[0] || 0),
                            "y": Number(at[1] || 0),
                            "w": Number(size[0] || 0),
                            "h": Number(size[1] || 0)
                        });
                        if (seen[c])
                            continue;
                        seen[c] = true;
                        classes.push(c);
                    }
                    root.openClients = clients;
                    root.openClasses = classes;
                    root.clientsTick += 1;
                } catch (e) {}
            }
        }
    }

    property Timer clientsTimer: Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            if (root.clientsPoll.running)
                return;
            root.clientsPoll.running = true;
            if (Hyprland.refreshToplevels)
                Hyprland.refreshToplevels();
        }
    }

    function focusClass(cls) {
        const c = String(cls || "");
        if (!c)
            return;
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "class:" + c]);
    }

    function closeAddress(addr) {
        let sel = String(addr || "");
        if (!sel)
            return;
        if (sel.indexOf("0x") !== 0 && sel.indexOf("0X") !== 0)
            sel = "0x" + sel;
        Quickshell.execDetached(["hyprctl", "eval", "(function() local w = hl.get_window(\"address:" + sel + "\"); if w then hl.dispatch(hl.dsp.window.close({ window = w })) end; return true end)()"]);
    }

    function closeClasses(classes) {
        const want = {};
        const list = classes || [];
        for (let i = 0; i < list.length; i++) {
            const key = String(list[i] || "").toLowerCase();
            if (key)
                want[key] = true;
        }
        const clients = root.openClients || [];
        for (let j = 0; j < clients.length; j++) {
            const c = String(clients[j].class || "").toLowerCase();
            let hit = !!want[c];
            if (!hit) {
                const keys = Object.keys(want);
                for (let k = 0; k < keys.length; k++) {
                    const n = keys[k];
                    if (c.indexOf(n) === 0 || n.indexOf(c) === 0 || c.indexOf(n + ".") === 0) {
                        hit = true;
                        break;
                    }
                }
            }
            if (hit)
                root.closeAddress(clients[j].address);
        }
    }
    property FileView gameFlagFile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/aurora-game"
        watchChanges: true
        blockLoading: false
        printErrors: false
        onFileChanged: this.reload()
    }
    readonly property bool gameFlagPresent: gameFlagFile.loaded

    onOverviewOpenChanged: {
        if (root.overviewOpen) {
            root.dismissScreenshot();
            root.closePreview();
        } else {
            root.clearOverviewDrag();
            root.packTimer.restart();
        }
    }

    onScreenshotOpenChanged: {
        if (root.screenshotOpen) {
            root.overviewOpen = false;
            root.closePreview();
        }
    }

    function toggleOverview() {
        if (!root.overviewOpen && root.isGameClient(Hyprland.activeToplevel))
            return;
        root.overviewOpen = !root.overviewOpen;
    }

    // In-process lock. Never `qs ipc call lock` from inside qs — a stale crash
    // marker makes that binary spawn another full shell (duplicate bars/docks).
    signal lockRequested

    function requestLock() {
        root.lockRequested();
    }

    function toggleScreenshot() {
        if (root.screenshotOpen || root.sattyOpen)
            root.dismissScreenshot();
        else
            root.screenshotOpen = true;
    }

    function toggleDesktopEdit() {
        root.desktopEdit = !root.desktopEdit;
    }

    function closeSatty() {
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            if (root.toplevelIsSatty(values[i]))
                root.closeWindow(values[i]);
        }
        const clients = root.openClients || [];
        for (let j = 0; j < clients.length; j++) {
            if (String(clients[j].class || "").indexOf("satty") === -1)
                continue;
            if (clients[j].address)
                root.closeAddress(clients[j].address);
        }
        Quickshell.execDetached(["sh", "-c", "pkill -x satty >/dev/null 2>&1 || true"]);
    }

    readonly property var sattyBox: {
        const _ = root.clientsTick + (root.sattyOpen ? 1 : 0);
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            const t = values[i];
            if (!root.toplevelIsSatty(t))
                continue;
            const ipc = t.lastIpcObject || {};
            const at = ipc.at || [0, 0];
            const size = ipc.size || [0, 0];
            const w = Number(size[0] || 0);
            const h = Number(size[1] || 0);
            if (w >= 8 && h >= 8)
                return {
                    "x": Number(at[0] || 0),
                    "y": Number(at[1] || 0),
                    "w": w,
                    "h": h
                };
        }
        const clients = root.openClients || [];
        for (let k = 0; k < clients.length; k++) {
            const c = clients[k];
            if (String(c.class || "").indexOf("satty") === -1)
                continue;
            if (Number(c.w) < 8 || Number(c.h) < 8)
                continue;
            return {
                "x": Number(c.x || 0),
                "y": Number(c.y || 0),
                "w": Number(c.w),
                "h": Number(c.h)
            };
        }
        return null;
    }

    function previewList(blob) {
        if (blob && typeof blob === "object" && blob.length !== undefined && typeof blob !== "string") {
            const arr = [];
            for (let i = 0; i < blob.length; i++) {
                const p = String(blob[i] || "").trim();
                if (p.length)
                    arr.push(p);
            }
            return arr;
        }
        const text = String(blob || "");
        if (!text.trim())
            return [];
        return text.split("\n").map(function (p) {
            return p.trim();
        }).filter(function (p) {
            return p.length > 0;
        });
    }

    function closePreview() {
        root.previewOpen = false;
        root.previewPath = "";
        root.previewPaths = [];
        root.previewIndex = 0;
    }

    function openPreview(blob) {
        const list = root.previewList(blob);
        if (!list.length)
            return;
        root.previewPaths = list;
        root.previewIndex = 0;
        root.previewPath = list[0];
        root.previewOpen = true;
    }

    function togglePreview(blob) {
        if (root.previewOpen) {
            root.closePreview();
            return;
        }
        root.openPreview(blob);
    }

    function previewStep(delta) {
        const list = root.previewPaths || [];
        if (list.length < 2)
            return;
        const n = list.length;
        let i = (root.previewIndex + delta) % n;
        if (i < 0)
            i += n;
        root.previewIndex = i;
        root.previewPath = list[i];
    }

    function dismissScreenshot() {
        root.screenshotOpen = false;
        root.sattySuppressUntil = 0;
        root.sattyDismissed = true;
        if (root.sattyOpen)
            root.closeSatty();
    }

    function toplevelIsSatty(t) {
        if (!t)
            return false;
        const ipc = t.lastIpcObject || {};
        const cls = String(ipc.class || ipc.initialClass || ipc.initial_class || t.className || "").toLowerCase();
        return cls.indexOf("satty") !== -1;
    }

    readonly property bool sattyFocused: root.toplevelIsSatty(Hyprland.activeToplevel)

    property Timer sattyBlurTimer: Timer {
        interval: 80
        repeat: false
        onTriggered: {
            if (!root.sattyOpen || root.sattyFocused || root.sattyDismissed)
                return;
            if (Date.now() < root.sattySuppressUntil)
                return;
            root.dismissScreenshot();
        }
    }

    onSattyFocusedChanged: {
        if (root.sattyOpen && !root.sattyFocused)
            root.sattyBlurTimer.restart();
    }

    // Ignore the focus bounce while Satty is mapping. Clicks outside are not gated by this.
    property double sattySuppressUntil: 0
    property bool sattyDismissed: false
    property int sattyBackdrop: 0
    property string sattyWsSnap: ""
    property bool sattyWsArmed: false

    function armSattySuppress() {
        root.sattySuppressUntil = Date.now() + 500;
    }

    readonly property bool sattyOpen: {
        const _ = root.clientsTick;
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            const t = values[i];
            const ipc = t.lastIpcObject || {};
            const cls = String(ipc.class || ipc.initialClass || ipc.initial_class || t.className || "").toLowerCase();
            if (cls.indexOf("satty") !== -1)
                return true;
        }
        const clients = root.openClients || [];
        for (let j = 0; j < clients.length; j++) {
            if (String(clients[j].class || "").indexOf("satty") !== -1)
                return true;
        }
        return false;
    }

    property Process sattyWsPoll: Process {
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.sattyOpen || !text)
                    return;
                try {
                    const data = JSON.parse(text);
                    if (!Array.isArray(data))
                        return;
                    const parts = [];
                    for (let i = 0; i < data.length; i++) {
                        const ws = data[i].activeWorkspace || {};
                        parts.push(String(data[i].name || i) + ":" + String(ws.id !== undefined ? ws.id : ""));
                    }
                    const sig = parts.join("|");
                    if (!root.sattyWsArmed) {
                        root.sattyWsSnap = sig;
                        root.sattyWsArmed = true;
                        return;
                    }
                    if (sig !== root.sattyWsSnap && Date.now() >= root.sattySuppressUntil)
                        root.dismissScreenshot();
                } catch (e) {}
            }
        }
    }

    property Timer sattyWsTimer: Timer {
        interval: 200
        repeat: true
        running: root.sattyOpen
        onTriggered: {
            if (root.sattyWsPoll.running)
                return;
            root.sattyWsPoll.running = true;
        }
    }

    // Any focused-workspace change (any monitor) closes the screenshot editor.
    readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) : 0

    onFocusedWorkspaceIdChanged: {
        if (root.focusedWorkspaceId <= 0)
            return;
        if (!root.sattyOpen && !root.screenshotOpen)
            return;
        if (Date.now() < root.sattySuppressUntil)
            return;
        root.dismissScreenshot();
    }

    function monitorIndex(name) {
        const order = root.monitorOrder;
        for (let i = 0; i < order.length; i++) {
            if (order[i] === name)
                return i;
        }
        const list = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values.slice() : [];
        list.sort(function (a, b) {
            return Number(a.x) - Number(b.x);
        });
        for (let j = 0; j < list.length; j++) {
            if (list[j].name === name)
                return j;
        }
        return 0;
    }

    function monitorAt(gx, gy) {
        const list = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [];
        let best = "";
        let bestD = 1e12;
        for (let i = 0; i < list.length; i++) {
            const m = list[i];
            const x = Number(m.x);
            const y = Number(m.y);
            const w = Number(m.width);
            const h = Number(m.height);
            if (gx >= x && gx < x + w && gy >= y && gy < y + h)
                return m.name;
            const cx = Math.max(x, Math.min(gx, x + w - 1));
            const cy = Math.max(y, Math.min(gy, y + h - 1));
            const d = (gx - cx) * (gx - cx) + (gy - cy) * (gy - cy);
            if (d < bestD) {
                bestD = d;
                best = m.name;
            }
        }
        return best;
    }

    function globalId(monitorName, localId) {
        return root.monitorIndex(monitorName) * root.workspacesPerMonitor + Number(localId);
    }

    function localId(globalId) {
        const id = Number(globalId);
        if (!(id >= 1))
            return 1;
        return ((id - 1) % root.workspacesPerMonitor) + 1;
    }

    function focusedMonitorName() {
        const focused = Hyprland.focusedMonitor;
        if (focused && focused.name)
            return focused.name;
        return root.monitorOrder[1] || root.monitorOrder[0];
    }

    function monitorNameForScreen(screen) {
        if (!screen)
            return root.monitorOrder[0];
        const hypr = Hyprland.monitorFor(screen);
        if (hypr && hypr.name)
            return hypr.name;
        return screen.name;
    }

    readonly property int gameLayoutRev: {
        let h = root.forceHideGameBar ? 1 : 0;
        h += root.gameFlagPresent ? 2 : 0;
        h += root.fsTick * 13;
        h += root.activeWindowFullscreen ? 5 : 0;
        h += root.activeWindowCovers ? 7 : 0;
        h += Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) * 31 : 0;
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            const t = values[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const fs = Number((t.fullscreen !== undefined ? t.fullscreen : ipc.fullscreen) || 0);
            const fsc = Number(ipc.fullscreenClient || 0);
            if (fs === 0 && fsc === 0 && !root.isGameClient(t))
                continue;
            h += 10 + fs + fsc * 3 + root.toplevelWorkspaceId(t) * 17;
        }
        return h;
    }

    function isDesktopMonitor(name) {
        if (name === "DP-1")
            return true;
        const screens = Quickshell.screens;
        return !!(screens && screens.length === 1);
    }

    function activeWorkspaceOnMonitor(monitorName) {
        const focused = Hyprland.focusedMonitor;
        if (focused && focused.name === monitorName) {
            const fw = Hyprland.focusedWorkspace;
            if (fw && fw.id !== undefined)
                return Number(fw.id);
        }
        const list = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [];
        for (let i = 0; i < list.length; i++) {
            const m = list[i];
            if (m.name !== monitorName)
                continue;
            if (m.activeWorkspace && m.activeWorkspace.id !== undefined)
                return Number(m.activeWorkspace.id);
            const ipc = m.lastIpcObject || {};
            const aw = ipc.activeWorkspace;
            if (aw && aw.id !== undefined)
                return Number(aw.id);
            if (typeof aw === "number")
                return aw;
        }
        return Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) : 1;
    }

    function isGameClient(t) {
        if (!t)
            return false;
        const ipc = t.lastIpcObject || {};
        if (ipc.mapped === false || ipc.hidden === true)
            return false;
        const cls = String(ipc.class || ipc.initialClass || ipc.initial_class || t.className || "").toLowerCase();
        const title = String(t.title || ipc.title || "").toLowerCase();
        if (cls.indexOf("steam_app_") !== -1 || cls.indexOf("gamescope") !== -1 || cls.indexOf("dota2") !== -1 || cls.indexOf("albion") !== -1)
            return true;
        if (cls.indexOf("prism") !== -1)
            return false;
        if (cls.indexOf("minecraft") !== -1)
            return true;
        if (title.indexOf("minecraft") !== -1 && (cls === "" || cls.indexOf("java") !== -1 || cls.indexOf("lwjgl") !== -1 || cls.indexOf("glfw") !== -1))
            return true;
        return false;
    }

    function toplevelWorkspaceId(t) {
        if (!t)
            return -1;
        if (t.workspace && t.workspace.id !== undefined)
            return Number(t.workspace.id);
        const ipc = t.lastIpcObject || {};
        const ws = ipc.workspace;
        if (ws && typeof ws === "object" && ws.id !== undefined)
            return Number(ws.id);
        if (typeof ws === "number")
            return ws;
        return -1;
    }

    function isMediaClient(t) {
        if (!t)
            return false;
        const ipc = t.lastIpcObject || {};
        const cls = String(ipc.class || ipc.initialClass || ipc.initial_class || t.className || "").toLowerCase();
        return cls.indexOf("google-chrome") !== -1 || cls === "chrome" || cls.indexOf("firefox") !== -1 || cls.indexOf("zen") !== -1 || cls === "mpv" || cls.indexOf("vlc") !== -1 || cls.indexOf("celluloid") !== -1;
    }

    function isExclusiveFullscreen(t) {
        if (!t)
            return false;
        const ipc = t.lastIpcObject || {};
        if (ipc.mapped === false || ipc.hidden === true)
            return false;
        const fs = Number((t.fullscreen !== undefined ? t.fullscreen : ipc.fullscreen) || 0);
        const fsc = Number(ipc.fullscreenClient || 0);
        return fs >= 2 || fsc >= 2;
    }

    function isVideoFullscreen(t) {
        if (!root.isMediaClient(t))
            return false;
        const ipc = t.lastIpcObject || {};
        if (ipc.mapped === false || ipc.hidden === true)
            return false;
        const fs = Number((t.fullscreen !== undefined ? t.fullscreen : ipc.fullscreen) || 0);
        const fsc = Number(ipc.fullscreenClient || 0);
        const content = String(ipc.content || ipc.contentType || "").toLowerCase();
        return fs >= 1 || fsc >= 1 || content.indexOf("video") !== -1;
    }

    function windowCoversMonitor(t, screen) {
        if (!t || !screen)
            return false;
        const ipc = t.lastIpcObject || {};
        if (ipc.mapped === false || ipc.hidden === true)
            return false;
        const at = ipc.at;
        const size = ipc.size;
        if (!at || !size)
            return false;
        const want = root.monitorNameForScreen(screen);
        const mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [];
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            if (m.name !== want)
                continue;
            const mx = Number(m.x || 0);
            const my = Number(m.y || 0);
            const mw = Number(m.width || 0);
            const mh = Number(m.height || 0);
            return Math.abs(Number(at[0]) - mx) <= 8 && Math.abs(Number(at[1]) - my) <= 8 && Number(size[0]) >= mw - 16 && Number(size[1]) >= mh - 16;
        }
        return false;
    }

    function gameFullscreenOnScreen(screen) {
        const _ = root.gameLayoutRev;
        if (!screen)
            return false;
        const want = root.monitorNameForScreen(screen);
        const active = root.activeWorkspaceOnMonitor(want);
        // forceHideGameBar / active FS apply only on the workspace that
        // is actually showing the game. GameMode used to blank every
        // desktop on DP-1 while Albion sat on workspace 4.
        if ((root.activeWindowFullscreen || root.activeWindowCovers) && (!root.activeWindowMonitor || root.activeWindowMonitor === want)) {
            const focusedWs = Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) : -1;
            if (focusedWs < 0 || active < 0 || focusedWs === active)
                return true;
        }
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            const t = values[i];
            if (!root.isToplevelOnScreen(t, screen))
                continue;
            const wsId = root.toplevelWorkspaceId(t);
            if (wsId >= 0 && active >= 0 && wsId !== active)
                continue;
            if (wsId < 0 && root.focusedMonitorName() !== want)
                continue;
            if (root.isGameClient(t) || root.isExclusiveFullscreen(t) || root.isVideoFullscreen(t) || root.windowCoversMonitor(t, screen))
                return true;
        }
        return false;
    }

    function isToplevelOnScreen(t, screen) {
        const want = root.monitorNameForScreen(screen);
        const mon = t.monitor;
        if (mon && mon.name)
            return mon.name === want;
        const ipc = t.lastIpcObject || {};
        if (ipc.monitor === undefined || ipc.monitor === null)
            return false;
        const monitors = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [];
        for (let i = 0; i < monitors.length; i++) {
            if (Number(monitors[i].id) === Number(ipc.monitor))
                return monitors[i].name === want;
        }
        return false;
    }

    function focusWorkspace(id) {
        const ws = Number(id);
        const list = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : [];
        for (let i = 0; i < list.length; i++) {
            if (Number(list[i].id) === ws && typeof list[i].activate === "function") {
                list[i].activate();
                return;
            }
        }
        Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = " + ws + " }))"]);
    }

    function focusLocalWorkspace(monitorName, localWs) {
        root.focusWorkspace(root.globalId(monitorName, localWs));
    }

    function workspaceLocalsOnMonitor(monitorName) {
        const _ = root.spaceRev;
        const count = root.workspacesPerMonitor;
        const out = [];
        for (let local = 1; local <= count; local++)
            out.push(local);
        return out;
    }

    function compactAllMonitors() {
    }

    function compactMonitor(monitorName) {
    }

    function rawOccupiedLocals(monitorName) {
        const base = root.monitorIndex(monitorName) * root.workspacesPerMonitor;
        const count = root.workspacesPerMonitor;
        const seen = {};
        const active = root.localId(root.activeWorkspaceOnMonitor(monitorName));
        if (active >= 1 && active <= count)
            seen[active] = true;
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id > base && id <= base + count)
                seen[id - base] = true;
        }
        const out = [];
        for (let local = 1; local <= count; local++) {
            if (seen[local])
                out.push(local);
        }
        return out;
    }

    function workspaceHasGame(globalId) {
        const want = Number(globalId);
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            if (root.isGameClient(tops[i]) && root.toplevelWorkspaceId(tops[i]) === want)
                return true;
        }
        return false;
    }

    function applySpaceOrder(monitorName, occupied) {
        const saved = root.spaceOrder[monitorName] || [];
        const used = {};
        const out = [];
        for (let i = 0; i < saved.length; i++) {
            const id = Number(saved[i]);
            if (occupied.indexOf(id) < 0 || used[id])
                continue;
            used[id] = true;
            out.push(id);
        }
        for (let i = 0; i < occupied.length; i++) {
            if (used[occupied[i]])
                continue;
            out.push(occupied[i]);
        }
        return out;
    }

    function setSpaceOrder(monitorName, locals) {
        const next = ({});
        const prev = root.spaceOrder || {};
        const keys = Object.keys(prev);
        const drop = String(monitorName);
        for (let i = 0; i < keys.length; i++) {
            if (keys[i] === drop)
                continue;
            next[keys[i]] = prev[keys[i]];
        }
        if (locals && locals.length)
            next[drop] = locals.slice();
        root.spaceOrder = next;
        root.spaceRev = root.spaceRev + 1;
    }

    function reorderSpaceToIndex(monitorName, fromLocal, insertIndex) {
        const list = root.workspaceLocalsOnMonitor(monitorName).slice();
        const from = Number(fromLocal);
        let fromIdx = -1;
        for (let i = 0; i < list.length; i++) {
            if (Number(list[i]) === from) {
                fromIdx = i;
                break;
            }
        }
        if (fromIdx < 0)
            return;
        let insert = Number(insertIndex);
        if (!(insert >= 0))
            insert = list.length;
        if (insert === fromIdx)
            return;
        list.splice(fromIdx, 1);
        if (insert > list.length)
            insert = list.length;
        list.splice(insert, 0, from);
        const saved = root.spaceOrder[monitorName] || [];
        if (saved.length === list.length) {
            let same = true;
            for (let i = 0; i < list.length; i++) {
                if (Number(saved[i]) !== Number(list[i])) {
                    same = false;
                    break;
                }
            }
            if (same)
                return;
        }
        root.setSpaceOrder(monitorName, list);
    }

    function windowsOnWorkspace(globalId) {
        const want = Number(globalId);
        const out = [];
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id === want)
                out.push(t);
        }
        if (out.length)
            return out;
        const clients = root.openClients || [];
        for (let j = 0; j < clients.length; j++) {
            if (Number(clients[j].workspace) !== want)
                continue;
            out.push({
                "lastIpcObject": {
                    "class": clients[j].class,
                    "title": clients[j].title,
                    "address": clients[j].address,
                    "workspace": {
                        "id": clients[j].workspace
                    }
                }
            });
        }
        return out;
    }

    function firstFreeLocal(monitorName, skip) {
        const skipMap = {};
        const extra = skip || [];
        for (let i = 0; i < extra.length; i++)
            skipMap[Number(extra[i])] = true;
        const base = root.monitorIndex(monitorName) * root.workspacesPerMonitor;
        const used = Object.assign({}, skipMap);
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const ipc = tops[i].lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = tops[i].workspace ? Number(tops[i].workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id > base && id <= base + root.workspacesPerMonitor)
                used[id - base] = true;
        }
        for (let local = 1; local <= root.workspacesPerMonitor; local++) {
            if (!used[local])
                return local;
        }
        return 0;
    }

    function moveWorkspaceTo(fromMon, fromLocal, toMon, toLocal) {
        const src = root.globalId(fromMon, fromLocal);
        const dest = root.globalId(toMon, toLocal);
        if (!(src >= 1) || !(dest >= 1) || src === dest)
            return;

        const srcWins = root.windowsOnWorkspace(src);
        const destWins = root.windowsOnWorkspace(dest);

        if (!destWins.length) {
            const cmds = [];
            for (let i = 0; i < srcWins.length; i++)
                cmds.push(root.moveWindowEval(srcWins[i], toMon, toLocal));
            if (cmds.length) {
                root.compacting = true;
                root.runSeq(cmds);
                root.packUnlock.restart();
            }
            return;
        }

        let tmpMon = fromMon;
        let tmpLocal = root.firstFreeLocal(fromMon, [fromLocal]);
        if (!(tmpLocal >= 1)) {
            tmpMon = toMon;
            tmpLocal = root.firstFreeLocal(toMon, [toLocal]);
        }
        if (!(tmpLocal >= 1)) {
            const cmds = [];
            for (let i = 0; i < srcWins.length; i++)
                cmds.push(root.moveWindowEval(srcWins[i], toMon, toLocal));
            if (cmds.length) {
                root.compacting = true;
                root.runSeq(cmds);
                root.packUnlock.restart();
            }
            return;
        }

        const cmds = [];
        for (let i = 0; i < srcWins.length; i++)
            cmds.push(root.moveWindowEval(srcWins[i], tmpMon, tmpLocal));
        for (let i = 0; i < destWins.length; i++)
            cmds.push(root.moveWindowEval(destWins[i], fromMon, fromLocal));
        for (let i = 0; i < srcWins.length; i++)
            cmds.push(root.moveWindowEval(srcWins[i], toMon, toLocal));
        if (!cmds.length)
            return;
        root.compacting = true;
        root.runSeq(cmds);
        root.packUnlock.restart();
    }

    function moveWindowEvalGlobal(t, destGlobal) {
        const sel = root.windowSelector(t);
        if (!sel || !(destGlobal >= 1))
            return "";
        return "hyprctl eval '" + root.hyprMoveLua(sel, destGlobal) + "'";
    }

    function moveWindowEval(t, monitorName, localWs) {
        return root.moveWindowEvalGlobal(t, root.globalId(monitorName, localWs));
    }

    function runSeq(cmds) {
        const list = [];
        for (let i = 0; i < cmds.length; i++) {
            if (cmds[i])
                list.push(cmds[i]);
        }
        if (!list.length)
            return;
        Quickshell.execDetached(["bash", "-lc", list.join(" && ")]);
    }

    function closeLocalWorkspace(monitorName, localWs) {
        const locals = root.workspaceLocalsOnMonitor(monitorName);
        if (locals.length <= 1)
            return 0;
        let dest = 0;
        for (let i = 0; i < locals.length; i++) {
            if (locals[i] !== localWs)
                continue;
            dest = i > 0 ? locals[i - 1] : Number(locals[i + 1] || 0);
            break;
        }
        if (!(dest >= 1))
            return 0;
        const src = root.globalId(monitorName, localWs);
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id === src)
                root.moveWindowToLocal(t, monitorName, dest);
        }
        const active = root.localId(root.activeWorkspaceOnMonitor(monitorName));
        if (active === localWs)
            root.focusLocalWorkspace(monitorName, dest);
        return dest;
    }

    function hyprFocusLua(sel) {
        return "(function() local w = hl.get_window(\"" + sel + "\"); if not w then return false end; hl.dispatch(hl.dsp.focus({ window = w })); return true end)()";
    }

    // XWayland clients have no t.wayland — wayland.activate() is a no-op
    // for Chrome, Steam, Discord, Telegram, most Electron. Always also
    // tell Hyprland to focus by address.
    function activateToplevel(t) {
        if (!t)
            return;
        if (t.wayland && typeof t.wayland.activate === "function")
            t.wayland.activate();
        const sel = root.windowSelector(t);
        if (!sel)
            return;
        Quickshell.execDetached(["hyprctl", "eval", root.hyprFocusLua(sel)]);
    }

    function focusWindow(t) {
        if (!t)
            return;
        const ipc = t.lastIpcObject || {};
        const ws = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
        if (ws)
            root.focusWorkspace(ws);
        root.activateToplevel(t);
    }

    // Launch from the current workspace: move the window here. Do not
    // jump the user to wherever that client first appeared.
    function bringWindow(t, destWs) {
        if (!t)
            return;
        const dest = Number(destWs);
        const at = root.toplevelWorkspaceId(t);
        if (dest >= 1 && at !== dest)
            root.moveWindowSilent(t, dest);
        if (dest >= 1)
            root.focusWorkspace(dest);
        root.activateToplevel(t);
    }

    function closeWindow(t) {
        if (!t)
            return;
        if (t.wayland && typeof t.wayland.close === "function") {
            t.wayland.close();
            return;
        }
        const addr = root.windowAddress(t);
        if (!addr)
            return;
        Quickshell.execDetached(["hyprctl", "eval", "(function() local w = hl.get_window(\"" + root.windowSelector(t) + "\"); if w then hl.dispatch(hl.dsp.window.close({ window = w })) end; return true end)()"]);
    }

    function windowAddress(t) {
        if (!t)
            return "";
        const ipc = t.lastIpcObject || {};
        let addr = String(ipc.address || t.address || "");
        if (!addr)
            return "";
        if (addr.indexOf("0x") !== 0 && addr.indexOf("0X") !== 0)
            addr = "0x" + addr;
        return addr;
    }

    function windowSelector(t) {
        const addr = root.windowAddress(t);
        return addr ? ("address:" + addr) : "";
    }

    function hyprMoveLua(sel, destGlobal) {
        return "(function() local w = hl.get_window(\"" + sel + "\"); if not w then return false end; hl.dispatch(hl.dsp.window.move({ workspace = " + destGlobal + ", window = w })); return true end)()";
    }

    function hyprMoveSilentLua(sel, destGlobal) {
        return "(function() local w = hl.get_window(\"" + sel + "\"); if not w then return false end; hl.dispatch(hl.dsp.window.move({ workspace = " + destGlobal + ", window = w, silent = true })); return true end)()";
    }

    function moveWindowToLocal(t, monitorName, localWs) {
        const sel = root.windowSelector(t);
        const dest = root.globalId(monitorName, localWs);
        if (!sel || !(dest >= 1))
            return;
        Quickshell.execDetached(["hyprctl", "eval", root.hyprMoveLua(sel, dest)]);
    }

    function moveWindowSilent(t, destGlobal) {
        const sel = root.windowSelector(t);
        const dest = Number(destGlobal);
        if (!sel || !(dest >= 1))
            return;
        Quickshell.execDetached(["hyprctl", "eval", root.hyprMoveSilentLua(sel, dest)]);
    }

    function swapWindows(a, b) {
        const sa = root.windowSelector(a);
        const sb = root.windowSelector(b);
        if (!sa || !sb || sa === sb)
            return;
        Quickshell.execDetached(["hyprctl", "eval", "(function() local a = hl.get_window(\"" + sa + "\"); local b = hl.get_window(\"" + sb + "\"); if a and b then hl.dispatch(hl.dsp.window.swap({ window = a, with = b })) end; return true end)()"]);
    }

    function beginOverviewDrag(t, monitorName, gx, gy) {
        root.overviewDrag = true;
        root.overviewDragKind = "window";
        root.overviewDragToplevel = t;
        root.overviewDragFromMonitor = monitorName;
        root.overviewDragFromLocal = root.localId(root.toplevelWorkspaceId(t));
        root.overviewDragX = gx;
        root.overviewDragY = gy;
        root.overviewDropMonitor = monitorName;
        root.overviewDropLocal = 0;
        root.overviewDropSwap = null;
        root.overviewDropPlus = false;
        root.overviewDropIndex = 0;
    }

    function beginOverviewSpaceDrag(monitorName, localWs, gx, gy) {
        root.overviewDrag = true;
        root.overviewDragKind = "space";
        root.overviewDragToplevel = null;
        root.overviewDragFromMonitor = monitorName;
        root.overviewDragFromLocal = Number(localWs) || 0;
        root.overviewDragX = gx;
        root.overviewDragY = gy;
        root.overviewDropMonitor = monitorName;
        root.overviewDropLocal = Number(localWs) || 0;
        root.overviewDropSwap = null;
        root.overviewDropPlus = false;
        root.overviewDropIndex = -1;
    }

    function updateOverviewDrag(gx, gy) {
        root.overviewDragX = gx;
        root.overviewDragY = gy;
    }

    function setOverviewDrop(monitorName, localWs, plus, swapToplevel, insertIndex) {
        root.overviewDropMonitor = monitorName || "";
        root.overviewDropLocal = Number(localWs) || 0;
        root.overviewDropPlus = !!plus;
        root.overviewDropSwap = swapToplevel || null;
        if (insertIndex !== undefined && insertIndex !== null)
            root.overviewDropIndex = Number(insertIndex);
    }

    function finishOverviewDrag() {
        const kind = root.overviewDragKind;
        const t = root.overviewDragToplevel;
        const fromMon = root.overviewDragFromMonitor;
        const fromLocal = root.overviewDragFromLocal;
        const mon = root.overviewDropMonitor;
        const local = root.overviewDropLocal;
        const plus = root.overviewDropPlus;
        const swap = root.overviewDropSwap;
        const insertIndex = root.overviewDropIndex;
        root.clearOverviewDrag();

        if (kind === "space") {
            if (!fromMon || !(fromLocal >= 1) || !mon)
                return;
            if (fromMon === mon) {
                if (plus)
                    root.reorderSpaceToIndex(mon, fromLocal, 99);
                else if (insertIndex >= 0)
                    root.reorderSpaceToIndex(mon, fromLocal, insertIndex);
                return;
            }
            let destLocal = plus ? root.firstFreeLocal(mon) : local;
            if (!(destLocal >= 1))
                destLocal = 1;
            root.moveWorkspaceTo(fromMon, fromLocal, mon, destLocal);
            return;
        }

        if (!t)
            return;
        if (mon && mon !== fromMon) {
            const destLocal = plus ? root.firstFreeLocal(mon) : (local >= 1 ? local : 1);
            if (destLocal >= 1)
                root.moveWindowToLocal(t, mon, destLocal);
            return;
        }
        if (swap && root.windowAddress(swap) && root.windowAddress(swap) !== root.windowAddress(t))
            root.swapWindows(t, swap);
        else if (plus && mon)
            root.moveWindowToLocal(t, mon, root.firstFreeLocal(mon));
        else if (mon && local >= 1)
            root.moveWindowToLocal(t, mon, local);
    }

    function clearOverviewDrag() {
        root.overviewDrag = false;
        root.overviewDragKind = "";
        root.overviewDragToplevel = null;
        root.overviewDragFromMonitor = "";
        root.overviewDragFromLocal = 0;
        root.overviewDropMonitor = "";
        root.overviewDropLocal = 0;
        root.overviewDropSwap = null;
        root.overviewDropPlus = false;
        root.overviewDropIndex = 0;
    }

    function fitSatty() {
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        let t = null;
        for (let i = 0; i < values.length; i++) {
            if (root.toplevelIsSatty(values[i])) {
                t = values[i];
                break;
            }
        }
        if (!t)
            return;
        const ipc = t.lastIpcObject || {};
        const mons = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [];
        let mon = null;
        for (let i = 0; i < mons.length; i++) {
            if (Number(mons[i].id) === Number(ipc.monitor)) {
                mon = mons[i];
                break;
            }
        }
        if (!mon)
            mon = Hyprland.focusedMonitor;
        if (!mon)
            return;
        const mw = Number(mon.width || 0);
        const mh = Number(mon.height || 0);
        if (mw < 200 || mh < 200)
            return;
        const mx = Number(mon.x || 0);
        const my = Number(mon.y || 0);
        const marginX = Math.max(80, Math.round(mw * 0.12));
        const marginY = Math.max(64, Math.round(mh * 0.10));
        const w = mw - marginX * 2;
        const h = mh - marginY * 2;
        const x = mx + marginX;
        const y = my + marginY;
        const addr = root.windowAddress(t);
        if (!addr)
            return;
        Quickshell.execDetached(["hyprctl", "--batch", "dispatch resizewindowpixel exact " + w + " " + h + ",address:" + addr + "; dispatch movewindowpixel exact " + x + " " + y + ",address:" + addr]);
    }

    property int sattyFitTries: 0

    property Timer sattyFitTimer: Timer {
        interval: 60
        repeat: true
        onTriggered: {
            root.fitSatty();
            root.sattyFitTries += 1;
            if (root.sattyFitTries >= 10)
                stop();
        }
    }

    onSattyOpenChanged: {
        if (root.sattyOpen) {
            root.sattyDismissed = false;
            root.sattyWsArmed = false;
            root.sattyWsSnap = "";
            root.sattyBackdrop += 1;
            root.armSattySuppress();
            root.sattyFitTries = 0;
            root.fitSatty();
            root.sattyFitTimer.restart();
        } else {
            root.sattySuppressUntil = 0;
            root.sattyWsArmed = false;
            root.sattyFitTimer.stop();
        }
    }

    property real capX: 0
    property real capY: 0
    property real capW: 0
    property real capH: 0
    property Timer captureWait: Timer {
        interval: 16
        repeat: false
        onTriggered: {
            Quickshell.execDetached([
                root.scripts + "/screenshot.sh",
                String(Math.round(root.capX)),
                String(Math.round(root.capY)),
                String(Math.round(root.capW)),
                String(Math.round(root.capH))
            ]);
        }
    }

    function captureRegion(x, y, w, h) {
        root.screenshotOpen = false;
        root.overviewOpen = false;
        root.armSattySuppress();
        root.capX = x;
        root.capY = y;
        root.capW = w;
        root.capH = h;
        root.captureWait.restart();
    }

    function runScreenshot() {
        root.toggleScreenshot();
    }
}
