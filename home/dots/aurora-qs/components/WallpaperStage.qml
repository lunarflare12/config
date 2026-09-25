import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell

import "../core" as Core
import "../services" as Services

// Fullscreen tilted spiral of cards for wallpapers, themes, and cursors.
Item {
    id: stage

    property var picker: null

    readonly property bool walls: stage.picker ? stage.picker.showingWalls : true
    readonly property bool themes: stage.picker ? stage.picker.showingThemes : false
    readonly property bool cursors: stage.picker ? stage.picker.showingCursors : false
    readonly property var items: stage.picker ? stage.picker.results : []
    readonly property int count: stage.items.length
    readonly property int selected: stage.picker ? stage.picker.selectedIndex : 0
    readonly property string poster: (Quickshell.env("HOME") || "/home/dd") + "/.local/state/aurora/wallpaper-poster.jpg"

    readonly property int viewW: Math.max(stage.width, 1600)
    readonly property int viewH: Math.max(stage.height, 900)
    readonly property int cardW: Math.round(Math.min(520, stage.viewW * 0.34))
    readonly property int cardH: Math.round(stage.cardW * 9 / 16)
    readonly property int span: 5

    function stillOf(path) {
        const raw = String(path || "");
        const walls = Services.WallpaperService.wallpapers || [];
        for (let i = 0; i < walls.length; i++) {
            if (walls[i].path === raw && walls[i].thumb)
                return walls[i].thumb;
        }
        if (Services.WallpaperService.isLivePath(raw))
            return stage.poster;
        if (raw.length)
            return raw;
        return stage.poster;
    }

    readonly property string preview: {
        if (stage.walls && stage.picker && stage.picker.previewPath.length)
            return stage.stillOf(stage.picker.previewPath);
        return stage.stillOf(Services.WallpaperService.current);
    }

    function offsetOf(index) {
        return index - stage.selected;
    }

    function slotX(offset) {
        return offset * Math.min(stage.viewW * 0.148, 248);
    }

    function slotY(offset) {
        return offset * offset * Math.min(stage.viewH * 0.016, 16);
    }

    function slotScale(offset) {
        const a = Math.abs(offset);
        if (a <= 0)
            return 1;
        if (a <= 1)
            return 0.90;
        if (a <= 2)
            return 0.70;
        if (a <= 3)
            return 0.52;
        if (a <= 4)
            return 0.40;
        return 0.32;
    }

    function slotRoll(offset) {
        return -offset * 5.2;
    }

    function slotOpacity(offset) {
        const a = Math.abs(offset);
        if (a <= 1)
            return 1;
        if (a <= 2)
            return 0.92;
        if (a <= 3)
            return 0.72;
        if (a <= 4)
            return 0.50;
        return 0.34;
    }

    function emptyText() {
        if (!stage.picker)
            return "";
        if (stage.walls) {
            if (Services.WallpaperService.scanning)
                return "Loading wallpapers...";
            return stage.picker.liveOnly ? "No live wallpapers" : (Services.WallpaperService.error || "No wallpapers in ~/Pictures/Wallpapers");
        }
        if (stage.cursors)
            return "No cursors";
        return "No themes";
    }

    Image {
        id: previewImage
        anchors.fill: parent
        visible: false
        asynchronous: true
        cache: true
        mipmap: true
        smooth: true
        fillMode: Image.PreserveAspectCrop
        source: stage.preview.length ? ("file://" + stage.preview) : ""
    }

    Rectangle {
        anchors.fill: parent
        color: Core.Theme.background
    }

    MultiEffect {
        anchors.fill: parent
        source: previewImage
        visible: previewImage.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 80
        blur: 1.0
        saturation: 0.85
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, previewImage.status === Image.Ready ? 0.42 : 0.28)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (stage.picker)
                stage.picker.dismiss();
        }
        onWheel: function (event) {
            if (!stage.picker)
                return;
            stage.picker.wheelAccumulator += event.angleDelta.y;
            while (Math.abs(stage.picker.wheelAccumulator) >= 120) {
                if (stage.picker.wheelAccumulator > 0) {
                    stage.picker.move(-1);
                    stage.picker.wheelAccumulator -= 120;
                } else {
                    stage.picker.move(1);
                    stage.picker.wheelAccumulator += 120;
                }
            }
            event.accepted = true;
        }
    }

    Item {
        id: chrome
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 72
        z: 20

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

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
                    readonly property bool on: stage.picker && stage.picker.mode === tab.modelData.id
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
                        onClicked: {
                            if (stage.picker)
                                stage.picker.setMode(tab.modelData.id);
                        }
                    }
                }
            }
        }

        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(360, stage.viewW * 0.36)
            height: 34
            radius: 17
            color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

            TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: Text.AlignVCenter
                color: "#FFFFFF"
                font.family: Core.Theme.fontFamily
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                text: stage.picker ? stage.picker.query : ""
                onActiveFocusChanged: {
                    if (stage.picker)
                        stage.picker.searchFocused = search.activeFocus;
                }
                onTextChanged: {
                    if (stage.picker)
                        stage.picker.query = search.text;
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: stage.walls ? "Search wallpapers..." : (stage.cursors ? "Search cursors..." : "Search themes...")
                    color: Qt.rgba(1, 1, 1, 0.38)
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 13
                    visible: !search.text.length && !search.activeFocus
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Rectangle {
                visible: stage.walls
                width: liveLabel.implicitWidth + 18
                height: 28
                radius: 8
                color: stage.picker && stage.picker.liveOnly ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                Text {
                    id: liveLabel
                    anchors.centerIn: parent
                    text: "Live"
                    color: stage.picker && stage.picker.liveOnly ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.78)
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: stage.picker && stage.picker.liveOnly ? Font.DemiBold : Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!stage.picker)
                            return;
                        stage.picker.liveOnly = !stage.picker.liveOnly;
                        if (stage.picker.liveOnly)
                            Services.WallpaperService.refresh();
                        stage.picker.selectedIndex = stage.picker.indexOfApplied();
                        stage.picker.wheelAccumulator = 0;
                    }
                }
            }

            Rectangle {
                visible: stage.cursors
                width: animLabel.implicitWidth + 18
                height: 28
                radius: 8
                color: stage.picker && stage.picker.animatedOnly ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                Text {
                    id: animLabel
                    anchors.centerIn: parent
                    text: "Animated"
                    color: stage.picker && stage.picker.animatedOnly ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.78)
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: stage.picker && stage.picker.animatedOnly ? Font.DemiBold : Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!stage.picker)
                            return;
                        stage.picker.animatedOnly = !stage.picker.animatedOnly;
                        stage.picker.selectedIndex = stage.picker.indexOfApplied();
                        stage.picker.wheelAccumulator = 0;
                    }
                }
            }

            Text {
                visible: stage.cursors
                anchors.verticalCenter: parent.verticalCenter
                text: "Size"
                color: Qt.rgba(1, 1, 1, 0.7)
                font.family: Core.Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            VolumeSlider {
                visible: stage.cursors
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
                visible: stage.cursors
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

    Item {
        id: ring
        anchors.fill: parent
        anchors.topMargin: 40
        z: 10

        Repeater {
            model: stage.count

            Item {
                id: card
                required property int index
                readonly property var item: stage.items[card.index] || null
                readonly property int offset: stage.offsetOf(card.index)
                readonly property bool on: card.offset === 0
                readonly property bool shown: Math.abs(card.offset) <= stage.span
                readonly property var swatch: card.item && card.item.colors ? card.item.colors : ({})
                readonly property string wallPath: card.item ? String(card.item.path || "") : ""
                readonly property bool live: stage.walls && !!card.wallPath && Services.WallpaperService.isLivePath(card.wallPath)
                readonly property bool gif: card.live && card.wallPath.toLowerCase().endsWith(".gif")
                readonly property string file: {
                    if (!card.item)
                        return "";
                    if (stage.cursors)
                        return card.item.thumb || "";
                    if (!stage.walls)
                        return "";
                    const path = card.wallPath;
                    // Live selected card plays via Video/AnimatedImage below.
                    if (card.live)
                        return card.item.thumb || stage.stillOf(path);
                    if (Math.abs(card.offset) <= 2 && path.length)
                        return path;
                    return card.item.thumb || stage.stillOf(path);
                }

                visible: card.shown && !!card.item
                width: stage.cardW
                height: stage.cardH
                x: Math.max(ring.width, stage.viewW) / 2 - width / 2 + stage.slotX(card.offset)
                y: Math.max(ring.height, stage.viewH) * 0.38 - height / 2 + stage.slotY(card.offset)
                z: 50 - Math.abs(card.offset)
                opacity: card.shown ? stage.slotOpacity(card.offset) : 0
                scale: stage.slotScale(card.offset)

                Behavior on x {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                rotation: stage.slotRoll(card.offset)

                Behavior on rotation {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 10
                    height: parent.height + 10
                    radius: 22
                    color: Qt.rgba(0, 0, 0, card.on ? 0.35 : 0.18)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: Qt.rgba(0.08, 0.08, 0.10, 0.72)
                    clip: true
                    border.width: 0

                    Image {
                        id: stillThumb
                        anchors.fill: parent
                        // Stay visible until live video/gif is actually playing.
                        visible: stage.walls && status === Image.Ready && !(liveLoader.item && liveLoader.item.playingReady)
                        asynchronous: true
                        cache: true
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 1280
                        sourceSize.height: 720
                        source: stage.walls && card.shown && card.file.length ? ("file://" + card.file) : ""
                    }

                    // Only the selected live card decodes. Thumb stays until playback is ready
                    // so a missing QtMultimedia backend never leaves a black card.
                    Loader {
                        id: liveLoader
                        anchors.fill: parent
                        active: stage.walls && card.on && card.live && card.shown && card.wallPath.length > 0
                        sourceComponent: card.gif ? liveGifComp : liveVideoComp
                    }

                    Component {
                        id: liveVideoComp
                        Video {
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                            muted: true
                            autoPlay: true
                            loops: MediaPlayer.Infinite
                            source: "file://" + card.wallPath
                            readonly property bool playingReady: playbackState === MediaPlayer.PlayingState
                        }
                    }

                    Component {
                        id: liveGifComp
                        AnimatedImage {
                            anchors.fill: parent
                            playing: true
                            asynchronous: true
                            cache: true
                            smooth: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 1280
                            sourceSize.height: 720
                            source: "file://" + card.wallPath
                            readonly property bool playingReady: status === Image.Ready && playing
                        }
                    }

                    AnimatedImage {
                        anchors.fill: parent
                        visible: stage.cursors && status === Image.Ready
                        playing: stage.cursors && card.shown && card.on
                        asynchronous: true
                        cache: true
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 360
                        sourceSize.height: 216
                        source: stage.cursors && card.shown && card.file.length ? ("file://" + card.file) : ""
                    }

                    Item {
                        anchors.fill: parent
                        visible: stage.themes

                        Rectangle {
                            anchors.fill: parent
                            color: stage.picker ? stage.picker.shade(card.swatch, "background", "#1c1c1e") : "#1c1c1e"
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 28
                            color: stage.picker ? stage.picker.shade(card.swatch, "surface", "#2c2c2e") : "#2c2c2e"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 8
                                radius: 4
                                color: stage.picker ? stage.picker.shade(card.swatch, "accent", Core.Theme.accent) : Core.Theme.accent
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 92
                                height: 6
                                radius: 3
                                color: stage.picker ? stage.picker.shade(card.swatch, "text", "#f5f5f7") : "#f5f5f7"
                            }

                            Rectangle {
                                width: 58
                                height: 6
                                radius: 3
                                color: stage.picker ? stage.picker.shade(card.swatch, "textMuted", "#98989d") : "#98989d"
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 16
                            spacing: 6

                            Repeater {
                                model: ["terminalRed", "terminalYellow", "terminalGreen", "terminalCyan", "terminalBlue", "terminalMagenta"]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: stage.picker ? stage.picker.shade(card.swatch, modelData, "#3a3a3c") : "#3a3a3c"
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 36
                        visible: !stage.themes
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: Qt.rgba(0, 0, 0, 0.55)
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        text: stage.picker ? stage.picker.labelOf(card.item) : ""
                        color: "#FFFFFF"
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: card.on ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!stage.picker || !card.item)
                            return;
                        stage.picker.selectedIndex = card.index;
                        stage.picker.applyItem(card.item);
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: stage.count === 0
            text: stage.emptyText()
            color: Qt.rgba(1, 1, 1, 0.45)
            font.family: Core.Theme.fontFamily
            font.pixelSize: 14
        }
    }
}
