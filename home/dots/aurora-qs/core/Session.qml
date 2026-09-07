pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    property bool overviewOpen: false
    property bool screenshotOpen: false

    readonly property string scripts: Quickshell.env("HOME") + "/.config/scripts"

    onOverviewOpenChanged: {
        if (root.overviewOpen) {
            root.screenshotOpen = false;
            Hyprland.refreshToplevels();
        }
    }

    onScreenshotOpenChanged: {
        if (root.screenshotOpen)
            root.overviewOpen = false;
    }

    function toggleOverview() {
        root.overviewOpen = !root.overviewOpen;
    }

    function toggleScreenshot() {
        root.screenshotOpen = !root.screenshotOpen;
    }

    function closeOverlays() {
        root.overviewOpen = false;
        root.screenshotOpen = false;
    }

    function isFullscreenGame(t) {
        if (!t)
            return false;
        const ipc = t.lastIpcObject || {};
        const fs = ipc.fullscreen;
        let on = false;
        if (typeof fs === "number")
            on = fs > 0;
        else if (typeof fs === "boolean")
            on = fs;
        else if (typeof fs === "string")
            on = fs !== "" && fs !== "0" && fs !== "false";
        else if (Array.isArray(fs))
            on = fs.some(function (v) {
                return Number(v) > 0;
            });
        if (!on)
            return false;
        const cls = String(ipc.class || ipc.initialClass || t.className || "");
        const title = String(t.title || ipc.title || "");
        return cls.indexOf("steam_app_") === 0 || cls.indexOf("gamescope") === 0 || title.indexOf("Overwatch") !== -1;
    }

    function gameFullscreenOnScreen(screen) {
        const values = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        for (let i = 0; i < values.length; i++) {
            if (root.isFullscreenGameOnScreen(values[i], screen))
                return true;
        }
        return root.isFullscreenGameOnScreen(Hyprland.activeToplevel, screen);
    }

    function isFullscreenGameOnScreen(t, screen) {
        if (!root.isFullscreenGame(t))
            return false;
        if (!screen)
            return true;
        const mon = t.monitor;
        if (mon && mon.name)
            return mon.name === screen.name;
        const ipc = t.lastIpcObject || {};
        if (ipc.monitor !== undefined && ipc.monitor !== null) {
            const monitors = (Hyprland.monitors && Hyprland.monitors.values) ? Hyprland.monitors.values : [];
            for (let i = 0; i < monitors.length; i++) {
                if (Number(monitors[i].id) === Number(ipc.monitor))
                    return monitors[i].name === screen.name;
            }
        }
        return true;
    }

    function runScreenshot(mode) {
        root.screenshotOpen = false;
        root.overviewOpen = false;
        Hyprland.dispatch("exec " + root.scripts + "/screenshot.sh " + mode);
    }
}
