import QtQuick
import "../core" as Core
import "../services" as Services

// Same bottom strip as wallpapers, with theme previews instead of photos.
FocusScope {
    id: picker

    readonly property bool open: Core.PopupManager.isOpen("theme")
    property bool hosted: false
    property int cardWidth: 0
    property int viewHeight: 0

    readonly property var results: Services.ThemeService.themes
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
        const theme = picker.results[picker.selectedIndex];
        if (!theme)
            return;
        picker.dismiss();
        if (theme.id === Services.ThemeService.activeId)
            return;
        Services.ThemeService.apply(theme.id);
    }

    function indexOfCurrent() {
        const cur = Services.ThemeService.activeId;
        for (let i = 0; i < picker.results.length; i++) {
            if (picker.results[i].id === cur)
                return i;
        }
        return 0;
    }

    function shade(palette, key, fallback) {
        const value = palette ? palette[key] : "";
        return (value && String(value).length > 0) ? value : fallback;
    }

    onOpenChanged: {
        if (!picker.open)
            return;
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
            text: "No matching colorschemes"
            color: Core.Theme.foregroundFaint
            font.family: Core.Theme.fontMono
            font.pixelSize: Core.Theme.fontSize
        }

        delegate: Item {
            id: cell

            required property var modelData
            required property int index

            readonly property bool selected: cell.index === picker.selectedIndex
            readonly property bool applied: cell.modelData.id === Services.ThemeService.activeId
            readonly property int faceW: cell.selected ? picker.heroW : picker.sliceW
            readonly property var palette: cell.modelData.colors || ({})

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
                color: picker.shade(cell.palette, "background", Core.Theme.background)
                border.width: cell.selected ? 2 : 1
                border.color: cell.selected ? picker.shade(cell.palette, "accent", Core.Theme.accent) : (cell.applied ? picker.shade(cell.palette, "accentMuted", Core.Theme.accentMuted) : Qt.rgba(1, 1, 1, 0.22))

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 22
                    color: picker.shade(cell.palette, "surface", Core.Theme.surface)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 8
                        radius: 4
                        color: picker.shade(cell.palette, "accent", Core.Theme.accent)
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.bottom: dots.top
                    anchors.bottomMargin: 12
                    spacing: 6

                    Rectangle {
                        width: Math.min(72, face.width - 24)
                        height: 6
                        radius: 3
                        color: picker.shade(cell.palette, "text", Core.Theme.foreground)
                    }

                    Rectangle {
                        width: Math.min(48, face.width - 24)
                        height: 6
                        radius: 3
                        color: picker.shade(cell.palette, "textMuted", Core.Theme.foregroundFaint)
                    }
                }

                Row {
                    id: dots
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    spacing: 5
                    visible: cell.selected || cell.faceW > 160

                    Repeater {
                        model: ["terminalRed", "terminalYellow", "terminalGreen", "terminalCyan", "terminalBlue", "terminalMagenta"]
                        delegate: Rectangle {
                            required property var modelData
                            width: 10
                            height: 10
                            radius: 5
                            color: picker.shade(cell.palette, modelData, Core.Theme.surfaceHover)
                        }
                    }
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
            return item ? item.name : "";
        }
        color: Core.Theme.foreground
        font.family: Core.Theme.fontFamily
        font.pixelSize: Core.Theme.fontSize
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.65)
    }
}
