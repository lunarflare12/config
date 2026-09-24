import QtQuick
import "../core" as Core
import "../services" as Services
import "../components" as Components

// Wallpapers, themes, and cursors in one bottom field.
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

    readonly property bool showingWalls: picker.mode === "wallpaper"
    readonly property bool showingThemes: picker.mode === "theme"
    readonly property bool showingCursors: picker.mode === "cursor"
    readonly property var results: {
        if (picker.mode === "theme")
            return Services.ThemeService.themes;
        if (picker.mode === "cursor")
            return Services.CursorService.filtered(picker.animatedOnly ? "animated" : "static");
        return Services.WallpaperService.wallpapers;
    }
    readonly property int itemCount: picker.results.length
    readonly property int tileW: 180
    readonly property int tileH: 108
    readonly property int gap: 12
    readonly property int barH: picker.tileH + 86 + (picker.showingCursors ? 36 : 0)
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
        if (picker.showingWalls) {
            const path = picker.previewPath.length > 0 ? picker.previewPath : Services.WallpaperService.current;
            return path === item.path;
        }
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
        Qt.callLater(function () {
            if (strip)
                strip.positionViewAtIndex(picker.selectedIndex, ListView.Center);
        });
    }

    function setMode(next) {
        const mode = (next === "theme" || next === "cursor") ? next : "wallpaper";
        if (picker.mode !== mode) {
            picker.mode = mode;
            picker.selectedIndex = picker.indexOfApplied();
            picker.wheelAccumulator = 0;
            Qt.callLater(function () {
                if (strip)
                    strip.positionViewAtIndex(picker.selectedIndex, ListView.Center);
            });
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
            return;
        }
        const cur = Core.PopupManager.current;
        picker.mode = (cur === "theme" || cur === "cursor") ? cur : "wallpaper";
        picker.previewPath = Services.WallpaperService.current;
        if (Services.WallpaperService.count === 0)
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
        if (picker.open && picker.hosted && strip)
            strip.positionViewAtIndex(picker.selectedIndex, ListView.Center);
    }

    function takeFocus() {
        if (!picker.open || !picker.hosted)
            return;
        picker.forceActiveFocus();
        if (strip)
            strip.positionViewAtIndex(picker.selectedIndex, ListView.Center);
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
        if (event.key === Qt.Key_Tab) {
            picker.setMode(picker.showingWalls ? "theme" : (picker.showingThemes ? "cursor" : "wallpaper"));
            event.accepted = true;
            return;
        }
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

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.36)
        z: 1
    }

    MouseArea {
        anchors.fill: parent
        z: 2
        onClicked: picker.dismiss()
        onWheel: function (event) {
            picker.wheelAccumulator += event.angleDelta.y;
            while (Math.abs(picker.wheelAccumulator) >= 120) {
                if (picker.wheelAccumulator > 0) {
                    picker.move(-1);
                    picker.wheelAccumulator -= 120;
                } else {
                    picker.move(1);
                    picker.wheelAccumulator += 120;
                }
            }
            event.accepted = true;
        }
    }

    Item {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: picker.barH
        z: 3
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.07, 0.07, 0.09, 0.82)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(1, 1, 1, 0.14)
        }

        Row {
            id: tabs
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 10
            spacing: 8
            height: 28

            Repeater {
                model: [
                    {
                        "id": "wallpaper",
                        "label": "Wallpapers"
                    },
                    {
                        "id": "theme",
                        "label": "Themes"
                    },
                    {
                        "id": "cursor",
                        "label": "Cursors"
                    }
                ]

                Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool on: picker.mode === tab.modelData.id
                    width: tabLabel.implicitWidth + 22
                    height: 28
                    radius: 8
                    color: tab.on ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        id: tabLabel
                        anchors.centerIn: parent
                        text: tab.modelData.label
                        color: tab.on ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.78)
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: tab.on ? Font.DemiBold : Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.setMode(tab.modelData.id)
                    }
                }
            }
        }

        Item {
            id: sizeBar
            visible: picker.showingCursors
            height: picker.showingCursors ? 28 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabs.bottom
            anchors.topMargin: picker.showingCursors ? 8 : 0
            anchors.leftMargin: 28
            anchors.rightMargin: 28

            Row {
                id: sizeRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                height: 28

                Rectangle {
                    id: animToggle
                    anchors.verticalCenter: parent.verticalCenter
                    width: animLabel.implicitWidth + 18
                    height: 26
                    radius: 8
                    color: picker.animatedOnly ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        id: animLabel
                        anchors.centerIn: parent
                        text: "Animated"
                        color: picker.animatedOnly ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.78)
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: picker.animatedOnly ? Font.DemiBold : Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            picker.animatedOnly = !picker.animatedOnly;
                            picker.selectedIndex = picker.indexOfApplied();
                            picker.wheelAccumulator = 0;
                            Qt.callLater(function () {
                                if (strip)
                                    strip.positionViewAtIndex(picker.selectedIndex, ListView.Center);
                            });
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Size"
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Components.VolumeSlider {
                    id: sizeSlider
                    width: 112
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    value: {
                        const steps = Services.CursorService.sizeSteps;
                        const cur = Services.CursorService.activeSize;
                        let idx = 0;
                        for (let i = 0; i < steps.length; i++) {
                            if (Math.abs(steps[i] - cur) < Math.abs(steps[idx] - cur))
                                idx = i;
                        }
                        return idx / Math.max(1, steps.length - 1);
                    }
                    onMoved: function (t) {
                        const steps = Services.CursorService.sizeSteps;
                        const idx = Math.round(t * (steps.length - 1));
                        Services.CursorService.applySize(steps[Math.max(0, Math.min(steps.length - 1, idx))]);
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    text: String(Services.CursorService.activeSize)
                    color: "#FFFFFF"
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        ListView {
            id: strip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sizeBar.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            orientation: ListView.Horizontal
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: picker.gap
            cacheBuffer: 2400
            reuseItems: true
            highlightFollowsCurrentItem: false
            model: picker.results
            currentIndex: picker.selectedIndex
            readonly property int contentW: picker.itemCount * picker.tileW + Math.max(0, picker.itemCount - 1) * picker.gap
            readonly property int sidePad: Math.max(28, Math.round((width - contentW) / 2))
            leftMargin: strip.sidePad
            rightMargin: strip.sidePad

            Text {
                anchors.centerIn: parent
                visible: picker.itemCount === 0
                text: picker.showingWalls ? (Services.WallpaperService.error || "No wallpapers in ~/Wallpapers") : (picker.showingCursors ? "No cursors" : "No themes")
                color: Qt.rgba(1, 1, 1, 0.45)
                font.family: Core.Theme.fontFamily
                font.pixelSize: 14
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool selected: cell.index === picker.selectedIndex
                readonly property bool applied: picker.isApplied(cell.modelData)
                readonly property var swatch: cell.modelData && cell.modelData.colors ? cell.modelData.colors : ({})

                width: picker.tileW
                height: picker.tileH + 26

                Rectangle {
                    id: face
                    width: picker.tileW
                    height: picker.tileH
                    anchors.top: parent.top
                    radius: 8
                    clip: true
                    color: picker.showingThemes ? picker.shade(cell.swatch, "background", "#1c1c1e") : Qt.rgba(0.08, 0.08, 0.1, 0.72)
                    border.width: (cell.selected || cell.applied) ? 2 : 0
                    border.color: cell.selected ? picker.accent : Qt.rgba(1, 1, 1, 0.35)

                    AnimatedImage {
                        id: thumbAnim
                        anchors.fill: parent
                        visible: picker.showingCursors && thumbAnim.status === Image.Ready
                        playing: picker.open && picker.showingCursors
                        asynchronous: true
                        cache: true
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 360
                        sourceSize.height: 216
                        source: {
                            const item = cell.modelData;
                            if (!item || !picker.showingCursors)
                                return "";
                            return item.thumb ? "file://" + item.thumb : "";
                        }
                    }

                    Image {
                        id: thumb
                        anchors.fill: parent
                        visible: picker.showingWalls && thumb.status === Image.Ready
                        asynchronous: true
                        cache: true
                        smooth: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 320
                        sourceSize.height: 200
                        source: {
                            const item = cell.modelData;
                            if (!item || !picker.showingWalls)
                                return "";
                            const file = item.thumb || item.path;
                            return file ? "file://" + file : "";
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: picker.showingThemes

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 20
                            color: picker.shade(cell.swatch, "surface", "#2c2c2e")

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 7
                                radius: 3
                                color: picker.shade(cell.swatch, "accent", picker.accent)
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.bottom: dots.top
                            anchors.bottomMargin: 10
                            spacing: 6

                            Rectangle {
                                width: 68
                                height: 5
                                radius: 3
                                color: picker.shade(cell.swatch, "text", "#f5f5f7")
                            }

                            Rectangle {
                                width: 44
                                height: 5
                                radius: 3
                                color: picker.shade(cell.swatch, "textMuted", "#98989d")
                            }
                        }

                        Row {
                            id: dots
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            spacing: 5

                            Repeater {
                                model: ["terminalRed", "terminalYellow", "terminalGreen", "terminalCyan", "terminalBlue", "terminalMagenta"]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 9
                                    height: 9
                                    radius: 5
                                    color: picker.shade(cell.swatch, modelData, "#3a3a3c")
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.top: face.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: picker.labelOf(cell.modelData)
                    color: cell.selected || cell.applied ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.78)
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: cell.selected ? Font.DemiBold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        picker.selectedIndex = cell.index;
                        picker.applyItem(cell.modelData);
                    }
                }
            }
        }
    }
}
