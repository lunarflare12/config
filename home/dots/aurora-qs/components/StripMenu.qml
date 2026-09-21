import QtQuick
import "../core" as Core

// Bottom strip menu used by wallpaper and theme pickers. No search bar.
FocusScope {
    id: menu

    property string popupId: ""
    property var items: []
    property string emptyText: ""
    property Component tile
    property var itemLabel: function (item) {
        return item ? (item.label || item.name || "") : "";
    }
    property var isApplied: function (item) {
        return false;
    }
    property var isSame: function (a, b) {
        return a === b;
    }

    signal applyRequested(var item)

    readonly property bool open: Core.PopupManager.isOpen(menu.popupId)
    property int cardWidth: 0
    property int viewHeight: 0
    property int selectedIndex: 0
    property real wheelAccumulator: 0

    readonly property int itemCount: menu.items ? menu.items.length : 0
    readonly property int sliceH: 188
    readonly property int sliceW: 112
    readonly property int heroW: 320
    readonly property int stripH: menu.sliceH + 16
    readonly property int gap: 10

    visible: menu.open
    focus: menu.open

    function dismiss() {
        if (menu.open)
            Core.PopupManager.close();
    }

    function move(delta) {
        if (menu.itemCount <= 0)
            return;
        menu.selectedIndex = Math.max(0, Math.min(menu.itemCount - 1, menu.selectedIndex + delta));
    }

    function applyCurrent() {
        const item = menu.items[menu.selectedIndex];
        if (!item)
            return;
        menu.applyRequested(item);
        menu.dismiss();
    }

    function selectIndex(index) {
        if (index < 0 || index >= menu.itemCount)
            return 0;
        return index;
    }

    onSelectedIndexChanged: {
        if (menu.open)
            strip.positionViewAtIndex(menu.selectedIndex, ListView.Center);
    }

    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            menu.dismiss();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            menu.applyCurrent();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) {
            menu.move(1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backtab) {
            menu.move(-1);
            event.accepted = true;
            return;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: menu.dismiss()
        onWheel: function (event) {
            menu.wheelAccumulator += event.angleDelta.y;
            while (Math.abs(menu.wheelAccumulator) >= 120) {
                if (menu.wheelAccumulator > 0) {
                    menu.move(-1);
                    menu.wheelAccumulator -= 120;
                } else {
                    menu.move(1);
                    menu.wheelAccumulator += 120;
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
        anchors.bottomMargin: Math.round(menu.height * 0.11)
        height: menu.stripH

        orientation: ListView.Horizontal
        clip: false
        boundsBehavior: Flickable.StopAtBounds
        interactive: false
        spacing: menu.gap
        cacheBuffer: 2400

        model: menu.items
        currentIndex: menu.selectedIndex
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: Math.round((width - menu.heroW) / 2)
        preferredHighlightEnd: Math.round((width + menu.heroW) / 2)
        highlightFollowsCurrentItem: true

        Text {
            anchors.centerIn: parent
            visible: menu.itemCount === 0
            text: menu.emptyText
            color: Core.Theme.foregroundFaint
            font.family: Core.Theme.fontMono
            font.pixelSize: Core.Theme.fontSize
        }

        delegate: Item {
            id: cell

            required property var modelData
            required property int index

            readonly property bool selected: cell.index === menu.selectedIndex
            readonly property bool applied: menu.isApplied(cell.modelData)
            readonly property int faceW: cell.selected ? menu.heroW : menu.sliceW

            width: cell.faceW
            height: menu.stripH
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
                height: menu.sliceH
                anchors.bottom: parent.bottom
                radius: 12
                clip: true
                color: Qt.rgba(0, 0, 0, 0.35)
                border.width: cell.selected ? 2 : 1
                border.color: cell.selected ? Core.Theme.accent : (cell.applied ? Core.Theme.accentMuted : Qt.rgba(1, 1, 1, 0.22))

                Loader {
                    anchors.fill: parent
                    anchors.margins: 0
                    sourceComponent: menu.tile
                    onLoaded: {
                        if (item) {
                            item.modelData = cell.modelData;
                            item.selected = Qt.binding(function () {
                                return cell.selected;
                            });
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !cell.selected
                    radius: face.radius
                    color: Qt.rgba(0, 0, 0, 0.08)
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    menu.selectedIndex = cell.index;
                    menu.applyCurrent();
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: strip.top
        anchors.bottomMargin: 10
        visible: menu.itemCount > 0
        text: menu.itemLabel(menu.items[menu.selectedIndex])
        color: Core.Theme.foreground
        font.family: Core.Theme.fontFamily
        font.pixelSize: Core.Theme.fontSize
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.65)
    }
}
