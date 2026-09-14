import QtQuick
import Quickshell
import Quickshell.Io
import "../components" as Components
import "../core" as Core
import "../services" as Services

// Wallpaper Picker

Components.LauncherView {
    id: launcher

    launcherId: "wallpaper"
    promptIcon: Core.Icons.image
    placeholder: "Search wallpapers"

    cardWidth: 760

    columns: 3

    // The wheel and h/j/k/l move the selection only -- nothing is applied
    // until Enter, so travelling through the grid is free.
    vimNavigation: true

    readonly property var results: Services.WallpaperService.search(launcher.query)

    itemCount: launcher.results.length

    counterText: launcher.query.length === 0 ? launcher.results.length + " wallpapers" : launcher.results.length + " of " + Services.WallpaperService.count

    onDidOpen: {
        if (Services.WallpaperService.count === 0)
            Services.WallpaperService.refresh();
    }

    onAccepted: {
        const item = launcher.results[launcher.selectedIndex];
        if (!item)
            return;

        launcher.dismiss();
        Services.WallpaperService.apply(item.path);
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            launcher.toggle();
        }

        function open(): void {
            launcher.show();
        }

        function close(): void {
            launcher.dismiss();
        }
    }

    contentComponent: Component {
        GridView {
            id: grid

            model: launcher.results
            currentIndex: launcher.selectedIndex

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 8192
            reuseItems: true

            interactive: false

            cellWidth: Math.floor(width / launcher.columns)
            cellHeight: Math.round(cellWidth * 0.70)

            onCurrentIndexChanged: grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)

            Text {
                anchors.centerIn: parent
                visible: launcher.results.length === 0 && !Services.WallpaperService.scanning

                text: Services.WallpaperService.error.length > 0 ? Services.WallpaperService.error : "No wallpapers in ~/Wallpapers"

                color: Core.Theme.foregroundFaint
                font.family: Core.Theme.fontMono
                font.pixelSize: Core.Theme.fontSize
            }

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                width: grid.cellWidth
                height: grid.cellHeight

                readonly property bool selected: cell.index === launcher.selectedIndex
                readonly property bool applied: Services.WallpaperService.current === cell.modelData.path

                // The selected tile grows past its own cell, so it has to paint
                // over its neighbours.
                z: cell.selected ? 3 : (cell.applied ? 1 : 0)

                Rectangle {
                    id: tile

                    anchors.fill: parent

                    // Headroom for the zoom. The selected tile grows past its
                    // own cell and the grid clips, so without a wider gutter
                    // the outer columns would get shaved flat as they scale.
                    anchors.margins: 8

                    // Rounded to match the rows in the battery popup.
                    radius: Core.Theme.radiusRow

                    color: Core.Theme.surfaceGlass
                    clip: true

                    Components.Tactile {
                        z: 8
                        anchors.fill: parent
                        radius: tile.radius
                        hovered: tileMouse.containsMouse
                        pressed: tileMouse.pressed
                        active: cell.selected
                        restScale: cell.selected ? 1.04 : 1.0
                        hoverScale: 1.06
                        pressScale: 0.96
                    }

                    opacity: 1.0

                    border.width: cell.selected ? Core.Theme.borderWidth * 2 : Core.Theme.borderWidth
                    border.color: cell.selected ? Core.Theme.accent : (cell.applied ? Core.Theme.accentMuted : Core.Theme.border)

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Core.Theme.durFast
                            easing.type: Easing.OutQuint
                        }
                    }

                    Image {
                        id: preview

                        anchors.fill: parent

                        asynchronous: false
                        cache: true
                        sourceSize.width: 384
                        sourceSize.height: 216
                        smooth: true
                        fillMode: Image.PreserveAspectCrop
                        source: {
                            const item = cell.modelData;
                            if (!item)
                                return "";
                            const file = item.thumb || item.path;
                            return file ? "file://" + file : "";
                        }

                        scale: cell.selected ? 1.16 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    // Filename plate
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        height: 26
                        color: Core.Theme.surfaceGlass

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 6

                            // Applied-wallpaper tick, matching the marker the
                            // battery popup puts on the live power profile.
                            Text {
                                anchors.verticalCenter: parent.verticalCenter

                                visible: cell.applied

                                text: Core.Icons.checkCircle

                                font.family: Core.Theme.iconFont
                                font.pixelSize: Core.Theme.iconSizeSmall

                                color: Core.Theme.accent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter

                                width: parent.width - (cell.applied ? 18 : 0)

                                text: cell.modelData.label
                                color: Core.Theme.foreground
                                font.family: Core.Theme.fontMono
                                font.pixelSize: Core.Theme.fontSizeSmall
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }

                MouseArea {
                    id: tileMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        launcher.selectedIndex = cell.index;
                        launcher.accepted();
                    }
                }
            }
        }
    }
}
