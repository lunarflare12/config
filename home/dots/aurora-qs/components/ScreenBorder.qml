import QtQuick
import Quickshell
import Quickshell.Wayland

import "../core" as Core

// Melting side/bottom frame. Right edge grows around an open bar panel.
PanelWindow {
    id: root

    property var modelData: null
    property string edge: "bottom"

    screen: root.modelData

    readonly property string monitorName: Core.Session.monitorNameForScreen(root.screen)
    readonly property bool onMain: Core.Session.isDesktopMonitor(root.monitorName)
    readonly property int thickness: Core.Theme.frameWidth
    readonly property int radius: Core.Theme.frameRadius
    readonly property color fillColor: Core.Theme.background
    readonly property int hit: 28
    readonly property bool mine: {
        const a = Core.PopupManager.anchorScreen;
        if (a)
            return a === root.screen;
        return root.monitorName === Core.Session.focusedMonitorName();
    }
    readonly property real sheetH: Core.PopupManager.rightSheetExtent
    readonly property real sheetW: Core.PopupManager.rightSheetWidth
    readonly property bool wrapRight: false
    readonly property int wrapExtra: root.thickness + root.radius
    readonly property real popupH: Math.max(0, root.sheetH - Core.Theme.notchHeight)

    implicitWidth: {
        if (root.edge === "left")
            return root.hit;
        if (root.edge === "right")
            return root.wrapRight ? Math.round(root.sheetW + root.wrapExtra) : root.hit;
        return 0;
    }
    implicitHeight: root.edge === "bottom" ? root.hit : 0

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    visible: !root.gameFullscreen && !root.hideHold

    property bool gameFullscreen: false
    property int fsWatch: Core.Session.fsTick
    property int ipcWatch: Core.Session.ipcReady
    property bool hideHold: false

    onFsWatchChanged: Qt.callLater(root.syncGameFullscreen)
    onIpcWatchChanged: Qt.callLater(root.syncGameFullscreen)
    function syncGameFullscreen() {
        const next = root.ipcWatch && Core.Session.gameFullscreenOnScreen(root.screen);
        if (root.gameFullscreen !== next)
            root.gameFullscreen = next;
    }
    Component.onCompleted: root.syncGameFullscreen()
    onGameFullscreenChanged: {
        if (root.gameFullscreen) {
            showDelay.stop();
            root.hideHold = true;
        } else {
            root.hideHold = true;
            showDelay.restart();
        }
    }

    Timer {
        id: showDelay
        interval: 480
        repeat: false
        onTriggered: root.hideHold = false
    }

    anchors {
        left: root.edge === "left" || root.edge === "bottom"
        right: root.edge === "right" || root.edge === "bottom"
        bottom: true
        top: root.edge !== "bottom"
    }

    margins.top: root.edge !== "bottom" ? Core.Theme.notchHeight : 0

    WlrLayershell.namespace: "aurora-frame-" + root.edge
    WlrLayershell.layer: WlrLayer.Overlay

    mask: passMask
    property Region passMask: Region {}

    Canvas {
        id: shape
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root
            function onFillColorChanged() {
                shape.requestPaint();
            }
            function onWrapRightChanged() {
                shape.requestPaint();
            }
            function onPopupHChanged() {
                shape.requestPaint();
            }
            function onSheetWChanged() {
                shape.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = root.fillColor;

            const w = width;
            const h = height;
            const t = root.thickness;
            const r = root.radius;

            if (root.edge === "left") {
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(t + r, 0);
                ctx.arcTo(t, 0, t, r, r);
                ctx.lineTo(t, h);
                ctx.lineTo(0, h);
                ctx.closePath();
                ctx.fill();
                return;
            }

            if (root.edge === "right") {
                if (root.wrapRight && root.popupH > r + t) {
                    const pl = Math.max(t + r, w - root.sheetW);
                    const pb = root.popupH;

                    ctx.beginPath();
                    ctx.rect(w - t, 0, t, h);
                    ctx.fill();

                    ctx.beginPath();
                    ctx.moveTo(pl, 0);
                    ctx.lineTo(pl - (t + r), 0);
                    ctx.arcTo(pl - t, 0, pl - t, r, r);
                    ctx.lineTo(pl - t, pb);
                    ctx.lineTo(pl, pb);
                    ctx.closePath();
                    ctx.fill();

                    ctx.beginPath();
                    ctx.rect(pl, pb, Math.max(0, w - t - pl), t);
                    ctx.fill();

                    ctx.beginPath();
                    ctx.moveTo(pl, pb);
                    ctx.lineTo(pl - (t + r), pb);
                    ctx.arcTo(pl - t, pb, pl - t, pb + r, r);
                    ctx.lineTo(pl - t, pb + t);
                    ctx.lineTo(pl, pb + t);
                    ctx.closePath();
                    ctx.fill();

                    ctx.beginPath();
                    ctx.moveTo(w, pb);
                    ctx.lineTo(w - (t + r), pb);
                    ctx.arcTo(w - t, pb, w - t, pb + r, r);
                    ctx.lineTo(w - t, pb + t);
                    ctx.lineTo(w, pb + t);
                    ctx.closePath();
                    ctx.fill();
                    return;
                }

                ctx.beginPath();
                ctx.moveTo(w, 0);
                ctx.lineTo(w - (t + r), 0);
                ctx.arcTo(w - t, 0, w - t, r, r);
                ctx.lineTo(w - t, h);
                ctx.lineTo(w, h);
                ctx.closePath();
                ctx.fill();
                return;
            }

            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(0, h);
            ctx.lineTo(w, h);
            ctx.lineTo(w, 0);
            ctx.lineTo(w - t, 0);
            ctx.arcTo(w - t, h - t, w - t - r, h - t, r);
            ctx.lineTo(t + r, h - t);
            ctx.arcTo(t, h - t, t, 0, r);
            ctx.lineTo(t, 0);
            ctx.closePath();
            ctx.fill();
        }
    }
}
