import QtQuick
import QtQuick.Effects
import "../core" as Core
import "../services" as Services
import "../components" as Components

// Wallpapers, themes, and cursors share the 3D ring.
FocusScope {
    id: picker

    readonly property bool open: Core.PopupManager.isOpen("wallpaper") || Core.PopupManager.isOpen("theme") || Core.PopupManager.isOpen("cursor")

    property bool hosted: false
    property int cardWidth: 0
    property int viewHeight: 0
    property string mode: "wallpaper"
    property int selectedIndex: 0
    property real wheelAccumulator: 0
    property string previewPath: ""
    property bool animatedOnly: false
    property bool liveOnly: false
    property string query: ""
    property bool searchFocused: false

    readonly property bool showingWalls: picker.mode === "wallpaper"
    readonly property bool showingThemes: picker.mode === "theme"
    readonly property bool showingCursors: picker.mode === "cursor"
    readonly property var results: {
        let all = [];
        if (picker.mode === "theme")
            all = Services.ThemeService.themes;
        else if (picker.mode === "cursor")
            all = Services.CursorService.filtered(picker.animatedOnly ? "animated" : "static");
        else
            all = Services.WallpaperService.filtered(picker.liveOnly ? "live" : "static");
        const q = String(picker.query || "").trim().toLowerCase();
        if (!q.length)
            return all;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const label = String(all[i].label || all[i].name || all[i].id || "").toLowerCase();
            if (label.indexOf(q) !== -1)
                out.push(all[i]);
        }
        return out;
    }
    readonly property int itemCount: picker.results.length
    readonly property color accent: Core.Theme.accent

    visible: picker.open && picker.hosted
    focus: picker.open && picker.hosted

    function dismiss() {
        if (picker.open)
            Core.PopupManager.close();
    }

    function shade(colors, key, fallback) {
        const value = colors ? colors[key] : "";
        return (value && String(value).length > 0) ? value : fallback;
    }

    function labelOf(item) {
        if (!item)
            return "";
        return item.label || item.name || item.id || "";
    }

    function isApplied(item) {
        if (!item)
            return false;
        if (picker.showingWalls)
            return item.path === Services.WallpaperService.current;
        if (picker.showingCursors)
            return item.id === Services.CursorService.activeId;
        return item.id === Services.ThemeService.activeId;
    }

    function indexOfApplied() {
        const list = picker.results;
        for (let i = 0; i < list.length; i++) {
            if (picker.isApplied(list[i]))
                return i;
        }
        return 0;
    }

    function syncFromPopup() {
        const cur = Core.PopupManager.current;
        const next = (cur === "theme" || cur === "cursor") ? cur : "wallpaper";
        if (picker.mode === next)
            return;
        picker.mode = next;
        picker.selectedIndex = picker.indexOfApplied();
        picker.wheelAccumulator = 0;
    }

    function setMode(next) {
        const mode = (next === "theme" || next === "cursor") ? next : "wallpaper";
        if (picker.mode !== mode) {
            picker.mode = mode;
            picker.query = "";
            picker.searchFocused = false;
            picker.selectedIndex = picker.indexOfApplied();
            picker.wheelAccumulator = 0;
        }
        if (picker.open && Core.PopupManager.current !== mode)
            Core.PopupManager.open(mode);
    }

    function move(delta) {
        if (picker.itemCount <= 0)
            return;
        picker.selectedIndex = Math.max(0, Math.min(picker.itemCount - 1, picker.selectedIndex + delta));
    }

    function applyItem(item) {
        if (!item)
            return;
        if (picker.showingWalls) {
            picker.previewPath = item.path || "";
            Services.WallpaperService.apply(item.path);
            return;
        }
        if (picker.showingCursors) {
            Services.CursorService.apply(item.id);
            return;
        }
        if (item.id !== Services.ThemeService.activeId)
            Services.ThemeService.apply(item.id);
    }

    function applyCurrent() {
        picker.applyItem(picker.results[picker.selectedIndex]);
    }

    onOpenChanged: {
        if (!picker.open) {
            picker.previewPath = "";
            picker.query = "";
            picker.searchFocused = false;
            return;
        }
        const cur = Core.PopupManager.current;
        picker.mode = (cur === "theme" || cur === "cursor") ? cur : "wallpaper";
        picker.previewPath = Services.WallpaperService.current;
        Services.WallpaperService.refresh();
        picker.selectedIndex = picker.indexOfApplied();
        picker.wheelAccumulator = 0;
        Qt.callLater(picker.takeFocus);
    }

    Connections {
        target: Core.PopupManager
        function onCurrentChanged() {
            if (picker.open)
                picker.syncFromPopup();
        }
    }

    onHostedChanged: {
        if (picker.open && picker.hosted)
            Qt.callLater(picker.takeFocus);
    }

    onSelectedIndexChanged: {
        if (picker.showingWalls && picker.results[picker.selectedIndex])
            picker.previewPath = picker.results[picker.selectedIndex].path || "";
    }

    onQueryChanged: picker.selectedIndex = picker.indexOfApplied();

    function takeFocus() {
        if (!picker.open || !picker.hosted)
            return;
        picker.forceActiveFocus();
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            picker.dismiss();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            picker.applyCurrent();
            event.accepted = true;
            return;
        }
        if (picker.searchFocused && (event.key === Qt.Key_Left || event.key === Qt.Key_Right))
            return;
        if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            picker.move(1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            picker.move(-1);
            event.accepted = true;
            return;
        }
    }

    Item {
        id: well
        anchors.fill: parent
        anchors.leftMargin: Core.Theme.dockReserve
        anchors.topMargin: Core.Theme.barHeight
        anchors.rightMargin: Core.Theme.outerGap
        anchors.bottomMargin: Core.Theme.outerGap

        Components.WallpaperStage {
            id: stageView
            anchors.fill: parent
            picker: picker
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: wellMask
            }
        }

        Rectangle {
            id: wellMask
            anchors.fill: stageView
            radius: Core.Theme.frameRadius
            color: "#FFFFFF"
            visible: false
            layer.enabled: true
            layer.smooth: true
        }
    }
}
