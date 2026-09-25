import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core
import "../services" as Services

// Brain Shell wallpaper drawer: grows out of the bottom center.
PanelWindow {
    id: root

    property var modelData: null
    screen: root.modelData

    readonly property bool mine: Core.PopupManager.anchorScreen ? Core.PopupManager.anchorScreen === root.screen : Core.Session.monitorNameForScreen(root.screen) === Core.Session.focusedMonitorName()
    readonly property bool wantOpen: Core.PopupManager.isOpen("edge-wallpaper") && root.mine
    property bool windowVisible: false
    property bool sheetOpen: false

    readonly property int fw: Core.Theme.frameRadius
    readonly property int panelWidth: 980
    readonly property int panelHeight: 420

    property string mode: "wallpaper"
    property string query: ""
    property string previewPath: ""

    readonly property var walls: Services.WallpaperService.wallpapers || []
    readonly property var themes: Services.ThemeService.themes || []
    readonly property var cursors: Services.CursorService.filtered("static") || []
    readonly property var rawItems: root.mode === "theme" ? root.themes : (root.mode === "cursor" ? root.cursors : root.walls)
    readonly property var items: {
        const q = String(root.query || "").trim().toLowerCase();
        const all = root.rawItems;
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
    readonly property bool applyActive: {
        if (root.mode !== "wallpaper")
            return false;
        return root.previewPath.length > 0 && root.previewPath !== Services.WallpaperService.current;
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.windowVisible
    exclusiveZone: 0

    WlrLayershell.namespace: "aurora-edge-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.wantOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onWantOpenChanged: {
        if (root.wantOpen) {
            closeTimer.stop();
            root.windowVisible = true;
            root.mode = Core.PopupManager.appearanceMode || "wallpaper";
            root.query = "";
            root.previewPath = Services.WallpaperService.current;
            Services.WallpaperService.refresh();
            Qt.callLater(function () {
                root.sheetOpen = true;
                searchInput.forceActiveFocus();
            });
            return;
        }
        root.sheetOpen = false;
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: 320
        onTriggered: {
            if (!root.wantOpen)
                root.windowVisible = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.wantOpen
        onClicked: Core.PopupManager.close()
    }

    Item {
        id: sheet
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        clip: true

        width: root.sheetOpen ? root.panelWidth + root.fw * 2 : Core.Theme.cNotchMinWidth + root.fw * 2
        height: root.sheetOpen ? root.panelHeight : 0

        Behavior on width {
            NumberAnimation {
                duration: 320
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 320
                easing.type: Easing.InOutCubic
            }
        }

        HoverHandler {
            onHoveredChanged: Core.PopupManager.setDrawerHover("edge-wallpaper", hovered)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        PopupShape {
            anchors.fill: parent
            attachedEdge: "bottom"
        }

        Column {
            id: body
            anchors.fill: parent
            anchors.leftMargin: root.fw + 16
            anchors.rightMargin: root.fw + 16
            anchors.topMargin: root.fw + 16
            anchors.bottomMargin: root.fw + 16
            spacing: 14
            opacity: root.sheetOpen ? 1 : 0
            transform: Translate {
                y: root.sheetOpen ? 0 : 36
                Behavior on y {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutExpo
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.sheetOpen ? 160 : 80
                }
            }

            ListView {
                id: strip
                width: parent.width
                height: parent.height - 48
                orientation: ListView.Horizontal
                spacing: 18
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.items

                Text {
                    anchors.centerIn: parent
                    visible: strip.count === 0
                    text: root.mode === "wallpaper" ? "No wallpapers found" : "Nothing here"
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.pixelSize: 13
                }

                delegate: Item {
                    id: card
                    required property var modelData
                    readonly property string path: String(modelData.path || "")
                    readonly property string thumb: String(modelData.thumb || modelData.path || "")
                    readonly property string label: String(modelData.label || modelData.name || modelData.id || "")
                    readonly property bool preview: root.mode === "wallpaper" && card.path.length > 0 && card.path === root.previewPath
                    readonly property bool current: {
                        if (root.mode === "theme")
                            return modelData.id === Services.ThemeService.activeId;
                        if (root.mode === "cursor")
                            return modelData.id === Services.CursorService.activeId;
                        return path.length && path === Services.WallpaperService.current;
                    }
                    width: card.preview ? 156 : 130
                    height: strip.height

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.InOutCubic
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: card.preview || card.current ? Qt.alpha(Core.Theme.accent, 0.14) : Qt.rgba(1, 1, 1, 0.04)
                        border.width: card.preview || card.current ? 2 : 0
                        border.color: Core.Theme.accent
                        clip: true

                        Image {
                            visible: root.mode === "wallpaper" && card.thumb.length
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: parent.height - 30
                            source: card.thumb.length ? "file://" + card.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        Rectangle {
                            visible: root.mode !== "wallpaper"
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: parent.height - 30
                            color: modelData.colors && modelData.colors.background ? modelData.colors.background : Core.Theme.surface

                            Rectangle {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                radius: 18
                                color: modelData.colors && modelData.colors.accent ? modelData.colors.accent : Core.Theme.accent
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 30
                            color: card.preview || card.current ? Qt.alpha(Core.Theme.accent, 0.22) : Qt.rgba(1, 1, 1, 0.09)

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 10
                                text: card.label
                                color: card.preview || card.current ? Core.Theme.accent : Qt.rgba(1, 1, 1, 0.65)
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.mode === "theme") {
                                Services.ThemeService.apply(modelData.id);
                                return;
                            }
                            if (root.mode === "cursor") {
                                Services.CursorService.apply(modelData.id);
                                return;
                            }
                            root.previewPath = card.path;
                        }
                        onDoubleClicked: {
                            if (root.mode === "wallpaper" && card.path.length) {
                                Services.WallpaperService.apply(card.path);
                                Core.PopupManager.close();
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 32

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.09)

                        Text {
                            anchors.centerIn: parent
                            text: "\udb80\ude4b"
                            color: Qt.rgba(1, 1, 1, 0.5)
                            font.pixelSize: 15
                        }
                    }

                    Rectangle {
                        width: 300
                        height: 32
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: searchInput.activeFocus ? Qt.alpha(Core.Theme.accent, 0.5) : Qt.rgba(1, 1, 1, 0.1)

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: root.mode === "theme" ? "Search themes..." : (root.mode === "cursor" ? "Search cursors..." : "Search wallpapers...")
                            color: Qt.rgba(1, 1, 1, 0.28)
                            font.pixelSize: 12
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: Core.Theme.text
                            font.pixelSize: 12
                            clip: true
                            onTextChanged: root.query = text
                            Keys.onEscapePressed: {
                                if (searchInput.text !== "")
                                    searchInput.text = "";
                                else
                                    Core.PopupManager.close();
                            }
                            Keys.onReturnPressed: {
                                if (root.mode === "wallpaper" && root.previewPath.length)
                                    Services.WallpaperService.apply(root.previewPath);
                                Core.PopupManager.close();
                            }
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.09)

                        Text {
                            anchors.centerIn: parent
                            text: "\udb83\udf58"
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.pixelSize: 14
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.applyActive ? 90 : 0
                    height: 32
                    radius: 8
                    clip: true
                    opacity: root.applyActive ? 1 : 0
                    color: Qt.alpha(Core.Theme.accent, applyHov.hovered ? 0.28 : 0.18)
                    border.width: 1
                    border.color: applyHov.hovered ? Core.Theme.accent : Qt.alpha(Core.Theme.accent, 0.4)

                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Apply"
                        color: Core.Theme.accent
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    HoverHandler {
                        id: applyHov
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.applyActive
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Services.WallpaperService.apply(root.previewPath);
                            Core.PopupManager.close();
                        }
                    }
                }
            }
        }
    }
}
