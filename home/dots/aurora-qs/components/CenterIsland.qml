import QtQuick

import "../core" as Core
import "../modules" as Modules
import "../services" as Services

// Center notch. One live face at a time. Super+wheel turns the next face in
// like a gear tooth when more than the clock is active.
Item {
    id: root

    property var screen: null
    property bool osd: false

    readonly property var island: Services.IslandService
    readonly property bool music: Services.MprisService.playing
    readonly property bool recording: Services.RecordService.recording

    onMusicChanged: root.island.sync(root.music, root.recording)
    onRecordingChanged: root.island.sync(root.music, root.recording)
    Component.onCompleted: root.island.sync(root.music, root.recording)

    function widthOf(kind) {
        if (kind === "music")
            return musicFace.implicitWidth;
        if (kind === "recording")
            return recFace.implicitWidth;
        return clock.implicitWidth;
    }

    function roleOf(kind) {
        if (kind === root.island.kind)
            return "current";
        if (root.island.busy && kind === root.island.nextKind)
            return "next";
        return "";
    }

    function angleOf(kind) {
        const role = root.roleOf(kind);
        if (role === "next")
            return (root.island.gear - 1) * 72 * root.island.direction;
        if (role === "current" && root.island.busy)
            return root.island.gear * 72 * root.island.direction;
        return 0;
    }

    readonly property int islandWidth: {
        const pad = 20;
        let raw = root.osd ? osdView.implicitWidth : root.widthOf(root.island.kind);
        if (!root.osd && root.island.busy)
            raw = Math.max(raw, root.widthOf(root.island.nextKind));
        return Math.max(Core.Theme.cNotchMinWidth - Core.Theme.notchPadding, Math.min(Core.Theme.cNotchMaxWidth - Core.Theme.notchPadding, raw + pad));
    }

    implicitWidth: root.islandWidth
    implicitHeight: Core.Theme.moduleHeight

    Item {
        id: inner
        anchors.centerIn: parent
        width: root.osd ? osdView.implicitWidth : (root.island.busy ? Math.max(root.widthOf(root.island.kind), root.widthOf(root.island.nextKind)) : root.widthOf(root.island.kind))
        height: Core.Theme.moduleHeight
        clip: true

        Modules.Clock {
            id: clock
            anchors.centerIn: parent
            reveal: 1
            opacity: !root.osd && root.roleOf("clock") !== "" ? (root.roleOf("clock") === "next" ? root.island.gear : 1 - root.island.gear * 0.35) : 0
            visible: opacity > 0.01
            transform: Rotation {
                origin.x: clock.width / 2
                origin.y: clock.height / 2
                axis {
                    x: 1
                    y: 0
                    z: 0
                }
                angle: root.angleOf("clock")
            }
        }

        Row {
            id: recFace
            anchors.centerIn: parent
            spacing: 8
            opacity: !root.osd && root.roleOf("recording") !== "" ? (root.roleOf("recording") === "next" ? root.island.gear : 1 - root.island.gear * 0.35) : 0
            visible: opacity > 0.01
            transform: Rotation {
                origin.x: recFace.width / 2
                origin.y: recFace.height / 2
                axis {
                    x: 1
                    y: 0
                    z: 0
                }
                angle: root.angleOf("recording")
            }

            Rectangle {
                id: recDot
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: 8
                radius: 4
                color: "#FF453A"

                SequentialAnimation on opacity {
                    running: root.recording
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1
                        to: 0.25
                        duration: 700
                    }
                    NumberAnimation {
                        from: 0.25
                        to: 1
                        duration: 700
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Recording"
                color: "#FF453A"
                font.family: Core.Theme.fontFamily
                font.pixelSize: Core.Theme.fontSizeSmall
                font.weight: Font.DemiBold
                renderType: Text.QtRendering
            }

            Rectangle {
                id: stopBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 7
                color: stopMouse.containsMouse ? "#FF6961" : "#FF453A"

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 1
                    color: "#1A1B26"
                }

                MouseArea {
                    id: stopMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.island.kind === "recording" && !root.island.busy
                    onClicked: Services.RecordService.stop()
                }
            }
        }

        Item {
            id: musicFace
            anchors.centerIn: parent
            implicitWidth: musicInner.implicitWidth
            implicitHeight: musicInner.implicitHeight
            width: implicitWidth
            height: implicitHeight
            opacity: !root.osd && root.roleOf("music") !== "" ? (root.roleOf("music") === "next" ? root.island.gear : 1 - root.island.gear * 0.35) : 0
            visible: opacity > 0.01
            transform: Rotation {
                origin.x: musicFace.width / 2
                origin.y: musicFace.height / 2
                axis {
                    x: 1
                    y: 0
                    z: 0
                }
                angle: root.angleOf("music")
            }

            Row {
                id: musicInner
                spacing: 8

                Modules.NowPlaying {
                    active: root.music
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: {
                            const t = Services.MprisService.title || "";
                            const a = Services.MprisService.artist || "";
                            if (t && a)
                                return t + "  ·  " + a;
                            return t || a || "Now Playing";
                        }
                        color: Core.Theme.text
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: Core.Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 240)
                        renderType: Text.QtRendering
                    }

                    Text {
                        text: Services.MprisService.playerLabel
                        color: Core.Theme.textMuted
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 240)
                        renderType: Text.QtRendering
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.island.kind === "music" && !root.island.busy
                onClicked: Services.MprisService.toggle()
            }
        }

        BarOsd {
            id: osdView
            anchors.centerIn: parent
            opacity: root.osd ? 1 : 0
        }
    }
}
