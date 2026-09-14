pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: root

    property bool overviewOpen: false
    property bool screenshotOpen: false
    property bool desktopEdit: false
    property int desktopMetricsCount: 0
    readonly property bool showDesktopMetrics: root.desktopMetricsCount > 0
    property bool overviewDrag: false
    property var overviewDragToplevel: null
    property string overviewDragFromMonitor: ""
    property real overviewDragX: 0
    property real overviewDragY: 0
    property string overviewDropMonitor: ""
    property int overviewDropLocal: 0
    property var overviewDropSwap: null
    property bool overviewDropPlus: false

    readonly property string scripts: Quickshell.env("HOME") + "/.config/scripts"
    readonly property int workspacesPerMonitor: 10
    readonly property var monitorOrder: ["HDMI-A-1", "DP-1"]
    readonly property string gameMonitor: "DP-1"
    property bool forceHideGameBar: false
    property FileView gameFlagFile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/aurora-game"
        watchChanges: true
        blockLoading: false
        printErrors: false
        onFileChanged: this.reload()
    }
    readonly property bool gameFlagPresent: gameFlagFile.loaded

    onOverviewOpenChanged: {
        if (root.overviewOpen)
            root.screenshotOpen = false;
        else
            root.clearOverviewDrag();
    }

    onScreenshotOpenChanged: {
        if (root.screenshotOpen)
            root.overviewOpen = false;
    }

    function toggleOverview() {
        if (!root.overviewOpen && root.isGameClient(Hyprland.activeToplevel))
            return;
        root.overviewOpen = !root.overviewOpen;
    }

    function toggleScreenshot() {
        root.screenshotOpen = !root.screenshotOpen;
    }

    function toggleDesktopEdit() {
        root.desktopEdit = !root.desktopEdit;
    }

    function closeOverlays() {
        root.overviewOpen = false;
        root.screenshotOpen = false;
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

    function isGameMonitorScreen(screen) {
        if (!screen)
            return false;
        const name = String(root.monitorNameForScreen(screen) || "");
        const sname = String(screen.name || "");
        if (name === root.gameMonitor || sname === root.gameMonitor)
            return true;
        if (name.indexOf("HDMI") !== -1 || sname.indexOf("HDMI") !== -1)
            return false;
        if (Number(screen.width) >= 2560)
            return true;
        const hypr = Hyprland.monitorFor(screen);
        if (hypr && (hypr.name === root.gameMonitor || Number(hypr.width) >= 2560))
            return true;
        return false;
    }

    readonly property int gameLayoutRev: {
        let h = root.forceHideGameBar ? 1 : 0;
        h += root.gameFlagPresent ? 2 : 0;
        h += Hyprland.focusedWorkspace ? Number(Hyprland.focusedWorkspace.id) * 31 : 0;
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            const t = values[i];
            if (!root.isGameClient(t))
                continue;
            const ipc = t.lastIpcObject || {};
            h += 10 + Number(ipc.fullscreen || 0) + Number(ipc.fullscreenClient || 0) * 3 + root.toplevelWorkspaceId(t) * 17;
        }
        return h;
    }

    readonly property bool gameRunning: {
        const _ = root.gameLayoutRev;
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            if (root.isGameClient(values[i]))
                return true;
        }
        return false;
    }

    function screenObject(name) {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0)
            return null;
        for (let i = 0; i < screens.length; i++) {
            if (root.monitorNameForScreen(screens[i]) === name)
                return screens[i];
        }
        return screens[0];
    }

    function screenOfItem(item) {
        let n = item;
        while (n) {
            if (n.screen)
                return n.screen;
            n = n.parent;
        }
        return root.screenObject(root.focusedMonitorName());
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
        if (cls.indexOf("steam_app_") !== -1 || cls.indexOf("gamescope") !== -1)
            return true;
        if (cls.indexOf("dota2") !== -1 || title.indexOf("dota 2") !== -1)
            return true;
        if (cls.indexOf("paladins") !== -1 || title.indexOf("paladins") !== -1)
            return true;
        if (cls.indexOf("overwatch") !== -1 || title.indexOf("overwatch") !== -1)
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

    function gameFullscreenOnScreen(screen) {
        const _ = root.gameLayoutRev;
        // Hide only on the workspace that actually has the game. Other desks
        // on this monitor (and HDMI) keep the bar.
        if (!screen)
            return false;
        const want = root.monitorNameForScreen(screen);
        const active = root.activeWorkspaceOnMonitor(want);
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            const t = values[i];
            if (!root.isGameClient(t) || !root.isToplevelOnScreen(t, screen))
                continue;
            const wsId = root.toplevelWorkspaceId(t);
            if (wsId >= 0 && active >= 0 && wsId !== active)
                continue;
            if (wsId < 0 && root.focusedMonitorName() !== want)
                continue;
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

    function isFullscreenGameOnScreen(t, screen) {
        if (!root.isGameClient(t))
            return false;
        const ipc = t.lastIpcObject || {};
        if (Number(ipc.fullscreen || 0) === 0 && Number(ipc.fullscreenClient || 0) === 0)
            return false;

        if (!root.isToplevelOnScreen(t, screen))
            return false;

        const want = root.monitorNameForScreen(screen);
        const wsId = root.toplevelWorkspaceId(t);
        const active = root.activeWorkspaceOnMonitor(want);
        if (wsId >= 0 && active >= 0 && wsId !== active)
            return false;
        return true;
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

    function focusWindow(t) {
        if (!t)
            return;
        const ipc = t.lastIpcObject || {};
        const ws = t.workspace ? Number(t.workspace.id) : Number(ipc.workspace && ipc.workspace.id);
        if (ws)
            root.focusWorkspace(ws);
        if (t.wayland && typeof t.wayland.activate === "function")
            t.wayland.activate();
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
        Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.window.close({ window = \"" + addr + "\" }))"]);
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

    function moveWindowToLocal(t, monitorName, localWs) {
        const addr = root.windowAddress(t);
        const dest = root.globalId(monitorName, localWs);
        if (!addr || !(dest >= 1))
            return;
        Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.window.move({ workspace = " + dest + ", window = \"" + addr + "\" }))"]);
    }

    function swapWindows(a, b) {
        const aa = root.windowAddress(a);
        const ab = root.windowAddress(b);
        if (!aa || !ab || aa === ab)
            return;
        Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.window.swap({ window = \"" + aa + "\", with = \"" + ab + "\" }))"]);
    }

    function beginOverviewDrag(t, monitorName, gx, gy) {
        root.overviewDrag = true;
        root.overviewDragToplevel = t;
        root.overviewDragFromMonitor = monitorName;
        root.overviewDragX = gx;
        root.overviewDragY = gy;
        root.overviewDropMonitor = monitorName;
        root.overviewDropLocal = 0;
        root.overviewDropSwap = null;
        root.overviewDropPlus = false;
    }

    function updateOverviewDrag(gx, gy) {
        root.overviewDragX = gx;
        root.overviewDragY = gy;
    }

    function setOverviewDrop(monitorName, localWs, plus, swapToplevel) {
        root.overviewDropMonitor = monitorName || "";
        root.overviewDropLocal = Number(localWs) || 0;
        root.overviewDropPlus = !!plus;
        root.overviewDropSwap = swapToplevel || null;
    }

    function finishOverviewDrag() {
        const t = root.overviewDragToplevel;
        const mon = root.overviewDropMonitor;
        const local = root.overviewDropLocal;
        const plus = root.overviewDropPlus;
        const swap = root.overviewDropSwap;
        root.clearOverviewDrag();
        if (!t)
            return;
        if (swap)
            root.swapWindows(t, swap);
        else if (plus && mon)
            root.moveWindowToLocal(t, mon, root.firstFreeLocal(mon));
        else if (mon && local >= 1)
            root.moveWindowToLocal(t, mon, local);
    }

    function firstFreeLocal(monitorName) {
        const base = root.monitorIndex(monitorName) * root.workspacesPerMonitor;
        const used = {};
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tops.length; i++) {
            const ipc = tops[i].lastIpcObject || {};
            if (ipc.mapped === false || ipc.hidden === true)
                continue;
            const id = tops[i].workspace ? Number(tops[i].workspace.id) : Number(ipc.workspace && ipc.workspace.id);
            if (id > base && id <= base + root.workspacesPerMonitor)
                used[id - base] = true;
        }
        const active = root.localId(root.activeWorkspaceOnMonitor(monitorName));
        used[active] = true;
        for (let local = 1; local <= root.workspacesPerMonitor; local++) {
            if (!used[local])
                return local;
        }
        return root.workspacesPerMonitor;
    }

    function clearOverviewDrag() {
        root.overviewDrag = false;
        root.overviewDragToplevel = null;
        root.overviewDragFromMonitor = "";
        root.overviewDropMonitor = "";
        root.overviewDropLocal = 0;
        root.overviewDropSwap = null;
        root.overviewDropPlus = false;
    }

    function runScreenshot(mode) {
        root.screenshotOpen = false;
        root.overviewOpen = false;
        Quickshell.execDetached([root.scripts + "/screenshot.sh", mode]);
    }
}
