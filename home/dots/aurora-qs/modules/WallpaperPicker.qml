import QtQuick
import "../core" as Core
import "../services" as Services

// Bottom wallpaper strip. Straight tiles, selected one is wider.
FocusScope {
    id: picker

    readonly property bool open: Core.PopupManager.isOpen("wallpaper")
    property bool hosted: false
    property int cardWidth: 0
    property int viewHeight: 0

    readonly property var results: Services.WallpaperService.wallpapers
    readonly property int itemCount: picker.results.length

    property int selectedIndex: 0
    property real wheelAccumulator: 0

    readonly property int sliceH: 188
    readonly property int sliceW: 112
    readonly property int heroW: 336
    readonly property int gap: 10
    readonly property int stripH: picker.sliceH + 16

    visible: picker.open && picker.hosted
    focus: picker.open && picker.hosted

    function dismiss() {
        if (picker.open)
            Core.PopupManager.close();
    }

    function move(delta) {
        if (picker.itemCount <= 0)
            return;
        picker.selectedIndex = Math.max(0, Math.min(picker.itemCount - 1, picker.selectedIndex + delta));
    }

    function applyCurrent() {
        const item = picker.results[picker.selectedIndex];
        if (!item)
            return;
        picker.dismiss();
        Services.WallpaperService.apply(item.path);
    }

    function indexOfCurrent() {
        const cur = Services.WallpaperService.current;
        if (!cur)
            return 0;
        for (let i = 0; i < picker.results.length; i++) {
            if (picker.results[i].path === cur)
                return i;
        }
        return 0;
    }

    onOpenChanged: {
        if (!picker.open)
            return;
        if (Services.WallpaperService.count === 0)
            Services.WallpaperService.refresh();
        picker.selectedIndex = picker.indexOfCurrent();
        picker.wheelAccumulator = 0;
        Qt.callLater(picker.takeFocus);
    }

    onHostedChanged: {
        if (picker.open && picker.hosted)
            Qt.callLater(picker.takeFocus);
    }

    function takeFocus() {
        if (!picker.open || !picker.hosted)
            return;
        picker.forceActiveFocus();
        strip.positionViewAtIndex(picker.selectedIndex, ListView.Center);
    }

    onSelectedIndexChanged: {
        if (picker.open && picker.hosted)
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
        if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
            picker.move(1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
            picker.move(-1);
            event.accepted = true;
            return;
        }
    }

    MouseArea {
        anchors.fill: parent
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

    ListView {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(picker.height * 0.11)
        height: picker.stripH

        orientation: ListView.Horizontal
        clip: false
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        reuseItems: true
        spacing: picker.gap
        cacheBuffer: 2400

        model: picker.results
        currentIndex: picker.selectedIndex
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: Math.round((width - picker.heroW) / 2)
        preferredHighlightEnd: Math.round((width + picker.heroW) / 2)
        highlightFollowsCurrentItem: true

        Text {
            anchors.centerIn: parent
            visible: picker.itemCount === 0
            text: Services.WallpaperService.error.length > 0 ? Services.WallpaperService.error : "No wallpapers in ~/Wallpapers"
            color: Core.Theme.foregroundFaint
            font.family: Core.Theme.fontMono
            font.pixelSize: Core.Theme.fontSize
        }

        delegate: Item {
            id: cell

            required property var modelData
            required property int index

            readonly property bool selected: cell.index === picker.selectedIndex
            readonly property bool applied: Services.WallpaperService.current === cell.modelData.path
            readonly property int faceW: cell.selected ? picker.heroW : picker.sliceW

            width: cell.faceW
            height: picker.stripH
            z: cell.selected ? 8 : (cell.applied ? 3 : 1)

            Behavior on width {
                NumberAnimation {
                    duration: Core.Theme.durBase
                    easing.type: Easing.OutQuint
                }
            }

            Rectangle {
                id: face

                width: cell.faceW
                height: picker.sliceH
                y: picker.stripH - height
                radius: 12
                clip: true
                color: Core.Theme.surface
                border.width: cell.selected ? 2 : 1
                border.color: cell.selected ? Core.Theme.accent : (cell.applied ? Core.Theme.accentMuted : Qt.rgba(1, 1, 1, 0.22))

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: 1
                    asynchronous: true
                    cache: true
                    sourceSize.width: cell.selected ? 640 : 220
                    sourceSize.height: 360
                    smooth: true
                    fillMode: Image.PreserveAspectCrop
                    visible: thumb.status === Image.Ready
                    source: {
                        const item = cell.modelData;
                        if (!item)
                            return "";
                        const file = item.thumb || item.path;
                        return file ? "file://" + file : "";
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !cell.selected
                    color: Qt.rgba(0, 0, 0, 0.08)
                    radius: face.radius
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    picker.selectedIndex = cell.index;
                    picker.applyCurrent();
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: strip.top
        anchors.bottomMargin: 10
        visible: picker.itemCount > 0
        text: {
            const item = picker.results[picker.selectedIndex];
            return item ? item.label : "";
        }
        color: Core.Theme.foreground
        font.family: Core.Theme.fontFamily
        font.pixelSize: Core.Theme.fontSize
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.65)
    }
}
