import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

import "../core" as Core
import "../services" as Services

// Compact now-playing card: art, wavy scrubber, prev / play / next.
// Background pulses with kick/bass from cava.
Item {
    id: root

    property var modelData: null
    property var host: parent

    readonly property string monitorName: root.host && root.host.monitorName ? root.host.monitorName : ""
    readonly property bool onDesktop: Core.Session.isWidgetMonitor(root.monitorName)
    readonly property var svc: Services.MprisService
    readonly property var cava: Services.CavaService
    readonly property bool wantCava: root.onDesktop && root.svc.playing

    property bool cavaHold: false

    function syncCava() {
        if (root.wantCava === root.cavaHold)
            return;
        root.cavaHold = root.wantCava;
        if (root.wantCava)
            root.cava.retain();
        else
            root.cava.release();
    }

    onWantCavaChanged: root.syncCava()
    Component.onCompleted: root.syncCava()
    Component.onDestruction: {
        if (root.cavaHold)
            root.cava.release();
    }

    anchors.fill: parent
    visible: root.onDesktop

    DesktopWidget {
        host: root.host
        widgetId: "now-playing"
        onDesktop: root.onDesktop
        framed: false
        spanW: 5
        spanH: 2
        defaultCol: 9
        defaultRow: 0
        contentComponent: playerContent
    }

    component MediaButton: Item {
        id: btn

        property string kind: "play"
        property bool armed: true
        signal activated

        readonly property bool big: btn.kind === "play" || btn.kind === "pause"

        implicitWidth: btn.big ? 46 : 40
        implicitHeight: 36
        width: implicitWidth
        height: implicitHeight
        opacity: btn.armed ? 1 : 0.35

        Tactile {
            anchors.fill: parent
            radius: 10
            hovered: hit.containsMouse
            pressed: hit.pressed
            feel: btn.armed
        }

        Item {
            anchors.centerIn: parent
            width: btn.big ? 18 : 20
            height: 16

            Row {
                anchors.centerIn: parent
                visible: btn.kind === "pause"
                spacing: 5

                Repeater {
                    model: 2
                    Rectangle {
                        width: 4
                        height: 16
                        radius: 1
                        color: Core.Theme.foreground
                    }
                }
            }

            Shape {
                anchors.fill: parent
                visible: btn.kind === "play"
                antialiasing: true

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Core.Theme.foreground
                    startX: 4
                    startY: 1
                    PathLine {
                        x: 16
                        y: 8
                    }
                    PathLine {
                        x: 4
                        y: 15
                    }
                    PathLine {
                        x: 4
                        y: 1
                    }
                }
            }

            Shape {
                anchors.fill: parent
                visible: btn.kind === "previous"
                antialiasing: true

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Core.Theme.foreground
                    startX: 10
                    startY: 2
                    PathLine {
                        x: 2
                        y: 8
                    }
                    PathLine {
                        x: 10
                        y: 14
                    }
                    PathLine {
                        x: 10
                        y: 2
                    }
                }

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Core.Theme.foreground
                    startX: 18
                    startY: 2
                    PathLine {
                        x: 10
                        y: 8
                    }
                    PathLine {
                        x: 18
                        y: 14
                    }
                    PathLine {
                        x: 18
                        y: 2
                    }
                }
            }

            Shape {
                anchors.fill: parent
                visible: btn.kind === "next"
                antialiasing: true

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Core.Theme.foreground
                    startX: 2
                    startY: 2
                    PathLine {
                        x: 10
                        y: 8
                    }
                    PathLine {
                        x: 2
                        y: 14
                    }
                    PathLine {
                        x: 2
                        y: 2
                    }
                }

                ShapePath {
                    strokeColor: "transparent"
                    fillColor: Core.Theme.foreground
                    startX: 10
                    startY: 2
                    PathLine {
                        x: 18
                        y: 8
                    }
                    PathLine {
                        x: 10
                        y: 14
                    }
                    PathLine {
                        x: 10
                        y: 2
                    }
                }
            }
        }

        MouseArea {
            id: hit
            anchors.fill: parent
            enabled: btn.armed
            hoverEnabled: true
            cursorShape: btn.armed ? Qt.PointingHandCursor : Qt.ArrowCursor
            preventStealing: true
            onClicked: btn.activated()
        }
    }

    Component {
        id: playerContent

        Item {
            id: body

            property real seekPreview: -1
            property real phase: 0

            readonly property real shownProgress: body.seekPreview >= 0 ? body.seekPreview : root.svc.progress
            readonly property var cavaValues: root.cava.values

            function css(c, a) {
                return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", " + Math.round(c.b * 255) + ", " + a + ")";
            }

            onCavaValuesChanged: wave.requestPaint()
            onShownProgressChanged: wave.requestPaint()
            onPhaseChanged: wave.requestPaint()

            Timer {
                interval: 33
                running: root.svc.playing
                repeat: true
                onTriggered: body.phase += 0.16 + root.cava.bass * 0.28
            }

            Rectangle {
                id: card

                anchors.fill: parent
                anchors.margins: 6
                radius: 0
                color: Core.Theme.background
                border.width: Core.Theme.borderWidth
                border.color: Core.Theme.borderActive
                clip: true

                Item {
                    id: spectrum

                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.bottomMargin: 8
                    z: 0

                    readonly property int count: root.cava.barCount
                    readonly property real gap: 3
                    readonly property var cavaValues: root.cava.values

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * 0.64
                        spacing: spectrum.gap

                        Repeater {
                            model: spectrum.count

                            Rectangle {
                                id: bar

                                required property int index

                                readonly property int src: {
                                    const n = spectrum.count;
                                    const half = Math.floor(n / 2);
                                    return bar.index < half ? bar.index : (n - 1 - bar.index);
                                }
                                readonly property real lvl: root.svc.playing ? root.cava.level(bar.src) : 0

                                width: Math.max(2, (spectrum.width - spectrum.gap * Math.max(0, spectrum.count - 1)) / Math.max(1, spectrum.count))
                                height: Math.max(2, parent.height * bar.lvl)
                                anchors.bottom: parent.bottom
                                radius: Math.min(3, width / 2)

                                gradient: Gradient {
                                    GradientStop {
                                        position: 0
                                        color: "#7EB2FF"
                                    }
                                    GradientStop {
                                        position: 0.4
                                        color: "#5B6CFF"
                                    }
                                    GradientStop {
                                        position: 1
                                        color: "#3A3E88"
                                    }
                                }

                                Behavior on height {
                                    enabled: !root.svc.playing
                                    NumberAnimation {
                                        duration: 220
                                        easing.type: Easing.OutQuint
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    z: 1
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52

                        Rectangle {
                            id: artWell
                            width: 52
                            height: 52
                            radius: 10
                            color: Core.Theme.surface
                            clip: true

                            Image {
                                id: art
                                anchors.fill: parent
                                source: root.svc.artSource
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: art.status !== Image.Ready
                                text: "♪"
                                color: Core.Theme.foregroundMuted
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: 20
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !Core.Session.desktopEdit && root.svc.canRaise
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.svc.raise()
                            }
                        }

                        Column {
                            anchors.left: artWell.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                width: parent.width
                                text: root.svc.available ? (root.svc.title !== "" ? root.svc.title : "Unknown track") : "No track"
                                elide: Text.ElideRight
                                color: Core.Theme.foreground
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                renderType: Text.NativeRendering
                            }

                            Text {
                                width: parent.width
                                text: root.svc.available ? (root.svc.artist !== "" ? root.svc.artist : root.svc.playerLabel) : "Nothing playing"
                                elide: Text.ElideRight
                                color: Core.Theme.foregroundMuted
                                font.family: Core.Theme.fontFamily
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28

                        Text {
                            id: elapsed
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            text: root.svc.lengthSupported ? root.svc.formatTime(body.shownProgress * root.svc.length) : "--:--"

                            color: Core.Theme.foregroundFaint
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: Core.Theme.fontSizeSmall
                            renderType: Text.NativeRendering
                        }

                        Text {
                            id: remain
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            horizontalAlignment: Text.AlignRight
                            text: {
                                if (!root.svc.lengthSupported)
                                    return "--:--";
                                return "-" + root.svc.formatTime(Math.max(0, root.svc.length * (1 - body.shownProgress)));
                            }
                            color: Core.Theme.foregroundFaint
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: Core.Theme.fontSizeSmall
                            renderType: Text.NativeRendering
                        }

                        Canvas {
                            id: wave

                            anchors.left: elapsed.right
                            anchors.right: remain.left
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: 22

                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (width < 8 || height < 8)
                                    return;

                                const n = root.cava.barCount;
                                const mid = height / 2;
                                const samples = Math.max(48, Math.floor(width / 3));
                                const live = root.svc.playing && root.cava.enabled;
                                const progress = Math.max(0, Math.min(1, body.shownProgress));
                                const accent = Core.Theme.accent;
                                const muted = Core.Theme.foregroundFaint;
                                const fg = Core.Theme.foreground;

                                function bandAt(t) {
                                    const x = t * Math.max(1, n - 1);
                                    const i = Math.max(0, Math.min(n - 2, Math.floor(x)));
                                    const f = x - i;
                                    return root.cava.level(i) * (1 - f) + root.cava.level(i + 1) * f;
                                }

                                function amp(t) {
                                    const energy = live ? bandAt(t) : 0.12;
                                    const pulse = 0.2 + energy * 0.8 + root.cava.beat * 0.18;
                                    const w = Math.sin(t * Math.PI * 6.2 + body.phase) * 0.62 + Math.sin(t * Math.PI * 13.4 + body.phase * 1.35) * 0.38;
                                    return Math.abs(w) * pulse;
                                }

                                function ribbon() {
                                    ctx.beginPath();
                                    ctx.moveTo(0, mid);
                                    for (let s = 0; s <= samples; s++) {
                                        const t = s / samples;
                                        ctx.lineTo(t * width, mid - amp(t) * height * 0.46);
                                    }
                                    for (let s = samples; s >= 0; s--) {
                                        const t = s / samples;
                                        ctx.lineTo(t * width, mid + amp(t) * height * 0.46);
                                    }
                                    ctx.closePath();
                                }

                                ctx.globalAlpha = 1;
                                ribbon();
                                ctx.fillStyle = body.css(muted, 0.28);
                                ctx.fill();
                                ctx.strokeStyle = body.css(muted, 0.7);
                                ctx.lineWidth = 1.4;
                                ctx.stroke();

                                ctx.save();
                                ctx.beginPath();
                                ctx.rect(0, 0, width * progress, height);
                                ctx.clip();
                                ribbon();
                                ctx.fillStyle = body.css(accent, 0.55);
                                ctx.fill();
                                ctx.strokeStyle = body.css(accent, 0.95);
                                ctx.lineWidth = 1.8;
                                ctx.stroke();
                                ctx.restore();

                                const kx = width * progress;
                                ctx.beginPath();
                                ctx.arc(kx, mid, 4.2, 0, Math.PI * 2);
                                ctx.fillStyle = body.css(fg, 0.95);
                                ctx.fill();
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.svc.canSeek && !Core.Session.desktopEdit
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                preventStealing: true

                                function apply(mx) {
                                    if (wave.width <= 0)
                                        return 0;
                                    return Math.max(0, Math.min(1, mx / wave.width));
                                }

                                onPressed: function (event) {
                                    body.seekPreview = apply(event.x);
                                }
                                onPositionChanged: function (event) {
                                    if (!pressed)
                                        return;
                                    body.seekPreview = apply(event.x);
                                }
                                onReleased: function (event) {
                                    root.svc.seekTo(apply(event.x));
                                    body.seekPreview = -1;
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Row {
                            anchors.centerIn: parent
                            spacing: 18

                            MediaButton {
                                kind: "previous"
                                armed: root.svc.canPrevious
                                onActivated: root.svc.previous()
                            }

                            MediaButton {
                                kind: root.svc.playing ? "pause" : "play"
                                armed: root.svc.canToggle
                                onActivated: root.svc.toggle()
                            }

                            MediaButton {
                                kind: "next"
                                armed: root.svc.canNext
                                onActivated: root.svc.next()
                            }
                        }
                    }
                }
            }
        }
    }
}
