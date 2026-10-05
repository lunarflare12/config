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
    // No stroke on side/bottom frames. The per-window hypr border is the
    // cyan outline; stroking here too made a second, broken line that never
    // quite met the bar. Fill still paints the melting chrome in the gaps.
    readonly property int strokeWidth: 0
    readonly property color strokeColor: Core.Theme.borderActive
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
    // Frame paints into the gaps_out band — do not reserve space or the
    // hypr border and aurora stroke double up with uneven padding.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    readonly property bool gameClass: {
        const cls = (Core.Session.activeWindowClass || "").toLowerCase();
        return cls.indexOf("steam_app_") !== -1
            || cls.indexOf("gamescope") !== -1
            || cls.indexOf("dota2") !== -1
            || cls.indexOf("minecraft") !== -1
            || cls.indexOf("albion") !== -1;
    }
    // Same hide rule as Bar.gameCovers — frames must vanish/reappear with
    // the notch, not linger as orphan strokes around a fullscreen game.
    readonly property bool gameHide: root.onMain
        && (root.gameClass || Core.Session.gameChromeLatched)
        && Core.Session.gameFullscreenOnScreen(root.screen)
    visible: !root.gameHide

    anchors {
        left: root.edge === "left" || root.edge === "bottom"
        right: root.edge === "right" || root.edge === "bottom"
        bottom: true
        top: root.edge !== "bottom"
    }

    // Overlap the bar by a few px. Exact abut at notchHeight left a hairline
    // seam between two layer-shell surfaces in the melting stroke.
    margins.top: root.edge !== "bottom" ? Math.max(0, Core.Theme.notchHeight - 3) : 0

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
            function onStrokeColorChanged() {
                shape.requestPaint();
            }
            function onStrokeWidthChanged() {
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
            const sw = root.strokeWidth;

            // Overlap joins with the bar / opposite frame so butt-clipping
            // cannot leave a one-pixel hole in the melting stroke.
            const join = Math.max(3, sw * 2);
            function strokeInner(draw) {
                if (sw <= 0)
                    return;
                ctx.save();
                ctx.clip();
                ctx.beginPath();
                draw();
                ctx.lineWidth = sw * 2;
                ctx.strokeStyle = root.strokeColor;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.stroke();
                ctx.restore();
            }

            if (root.edge === "left") {
                // Fill keeps the melting L-lip; stroke is vertical only.
                // Drawing the top arc here fought the bar stroke and left a
                // visible gap at the handoff. The bar owns the horizontal.
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(t + r, 0);
                ctx.arcTo(t, 0, t, r, r);
                ctx.lineTo(t, h);
                ctx.lineTo(0, h);
                ctx.closePath();
                ctx.fill();
                const stopY = Math.max(r, h - root.hit + join);
                strokeInner(function () {
                    ctx.moveTo(t, -join);
                    ctx.lineTo(t, stopY);
                });
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
                const stopYR = Math.max(r, h - root.hit + join);
                strokeInner(function () {
                    ctx.moveTo(w - t, -join);
                    ctx.lineTo(w - t, stopYR);
                });
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
            // Start above the panel top so the side-frame vertical overlaps.
            strokeInner(function () {
                ctx.moveTo(t, -join);
                ctx.lineTo(t, 0);
                ctx.arcTo(t, h - t, t + r, h - t, r);
                ctx.lineTo(w - t - r, h - t);
                ctx.arcTo(w - t, h - t, w - t, 0, r);
                ctx.lineTo(w - t, -join);
            });
        }
    }
}
