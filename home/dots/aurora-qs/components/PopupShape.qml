import QtQuick

import "../core" as Core

// Melting popup body from Brain Shell. attachedEdge: left|right|bottom|bottom-right
Canvas {
    id: root

    property string attachedEdge: "bottom"
    property color fill: Core.Theme.background
    property int radius: Core.Theme.frameRadius
    property int flareWidth: Core.Theme.frameRadius
    property int flareHeight: Core.Theme.frameRadius
    property int strokeWidth: Core.Theme.borderWidth
    property color strokeColor: Core.Theme.borderActive

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onAttachedEdgeChanged: requestPaint()
    onFillChanged: requestPaint()
    onFlareWidthChanged: requestPaint()
    onFlareHeightChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onStrokeColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width;
        const h = height;
        const r = root.radius;
        const fw = root.flareWidth;
        const fh = root.flareHeight;
        ctx.beginPath();
        ctx.fillStyle = root.fill;

        if (root.attachedEdge === "notch-center") {
            const nr = Math.max(1, r);
            ctx.moveTo(0, nr);
            ctx.arcTo(0, 0, nr, 0, nr);
            ctx.lineTo(w - nr, 0);
            ctx.arcTo(w, 0, w, nr, nr);
            ctx.lineTo(w, h - nr);
            ctx.arcTo(w, h, w - nr, h, nr);
            ctx.lineTo(nr, h);
            ctx.arcTo(0, h, 0, h - nr, nr);
            ctx.closePath();
        } else if (root.attachedEdge === "notch-right") {
            const nr = Math.max(1, Math.min(r, h / 2));
            ctx.moveTo(0, 0);
            ctx.lineTo(w, 0);
            ctx.lineTo(w, h - nr);
            ctx.arcTo(w, h, w - nr, h, nr);
            ctx.lineTo(nr, h);
            ctx.arcTo(0, h, 0, h - nr, nr);
            ctx.closePath();
        } else if (root.attachedEdge === "top") {
            ctx.moveTo(0, 0);
            ctx.quadraticCurveTo(fw, 0, fw, fh);
            ctx.lineTo(fw, h - r);
            ctx.arcTo(fw, h, fw + r, h, r);
            ctx.lineTo(w - fw - r, h);
            ctx.arcTo(w - fw, h, w - fw, h - r, r);
            ctx.lineTo(w - fw, fh);
            ctx.quadraticCurveTo(w - fw, 0, w, 0);
            ctx.closePath();
        } else if (root.attachedEdge === "right") {
            ctx.moveTo(w, 0);
            ctx.quadraticCurveTo(w, fh, w - fw, fh);
            ctx.lineTo(r, fh);
            ctx.arcTo(0, fh, 0, fh + r, r);
            ctx.lineTo(0, h - fh - r);
            ctx.arcTo(0, h - fh, r, h - fh, r);
            ctx.lineTo(w - fw, h - fh);
            ctx.quadraticCurveTo(w, h - fh, w, h);
            ctx.closePath();
        } else if (root.attachedEdge === "left") {
            ctx.moveTo(0, 0);
            ctx.quadraticCurveTo(0, fh, fw, fh);
            ctx.lineTo(w - r, fh);
            ctx.arcTo(w, fh, w, fh + r, r);
            ctx.lineTo(w, h - fh - r);
            ctx.arcTo(w, h - fh, w - r, h - fh, r);
            ctx.lineTo(fw, h - fh);
            ctx.quadraticCurveTo(0, h - fh, 0, h);
            ctx.closePath();
        } else if (root.attachedEdge === "bottom-right") {
            ctx.moveTo(fw + r, fh);
            ctx.lineTo(w - fw, fh);
            ctx.quadraticCurveTo(w, fh, w, 0);
            ctx.lineTo(w, h);
            ctx.lineTo(0, h);
            ctx.quadraticCurveTo(fw, h, fw, h - fh);
            ctx.lineTo(fw, fh + r);
            ctx.arcTo(fw, fh, fw + r, fh, r);
            ctx.closePath();
        } else {
            ctx.moveTo(0, h);
            ctx.quadraticCurveTo(fw, h, fw, h - fh);
            ctx.lineTo(fw, r);
            ctx.arcTo(fw, 0, fw + r, 0, r);
            ctx.lineTo(w - fw - r, 0);
            ctx.arcTo(w - fw, 0, w - fw, r, r);
            ctx.lineTo(w - fw, h - fh);
            ctx.quadraticCurveTo(w - fw, h, w, h);
            ctx.closePath();
        }
        ctx.fill();

        if (root.strokeWidth <= 0)
            return;
        if (root.attachedEdge !== "notch-right" && root.attachedEdge !== "notch-center")
            return;

        // Desktop-facing edge only. The screen top and the outer side stay bare,
        // same as the bar.
        ctx.save();
        ctx.clip();
        ctx.beginPath();
        const nr = Math.max(1, Math.min(r, h / 2));
        if (root.attachedEdge === "notch-right") {
            ctx.moveTo(0, 0);
            ctx.lineTo(0, h - nr);
            ctx.arcTo(0, h, nr, h, nr);
            ctx.lineTo(w - nr, h);
            ctx.arcTo(w, h, w, h - nr, nr);
        } else {
            ctx.moveTo(0, nr);
            ctx.lineTo(0, h - nr);
            ctx.arcTo(0, h, nr, h, nr);
            ctx.lineTo(w - nr, h);
            ctx.arcTo(w, h, w, h - nr, nr);
            ctx.lineTo(w, nr);
            ctx.arcTo(w, 0, w - nr, 0, nr);
        }
        ctx.lineWidth = root.strokeWidth * 2;
        ctx.strokeStyle = root.strokeColor;
        ctx.lineJoin = "round";
        ctx.lineCap = "butt";
        ctx.stroke();
        ctx.restore();
    }
}
