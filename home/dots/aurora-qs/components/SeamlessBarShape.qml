import QtQuick

import "../core" as Core

// Three melting notches + a thin top strip. Ported from Brain Shell.
Canvas {
    id: root

    property int leftWidth: Core.Theme.lNotchMinWidth
    property int centerWidth: Core.Theme.cNotchMinWidth
    property int rightWidth: Core.Theme.rNotchMinWidth
    property int notchHeight: Core.Theme.notchHeight
    property int radius: Core.Theme.notchRadius
    property int topBorderWidth: Core.Theme.frameWidth
    property color fill: Core.Theme.background
    property int strokeWidth: Core.Theme.borderWidth
    property color strokeColor: Core.Theme.borderActive

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLeftWidthChanged: requestPaint()
    onCenterWidthChanged: requestPaint()
    onRightWidthChanged: requestPaint()
    onFillChanged: requestPaint()
    onStrokeWidthChanged: requestPaint()
    onStrokeColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const leftW = root.leftWidth;
        const centerW = root.centerWidth;
        const rightW = root.rightWidth;
        const r = root.radius;
        const h = root.notchHeight;
        const b = root.topBorderWidth;
        const w = width;
        const centerStart = (w / 2) - (centerW / 2);
        const centerEnd = (w / 2) + (centerW / 2);
        const rightStart = w - rightW;

        function traceInner() {
            ctx.moveTo(0, h);
            ctx.lineTo(leftW - r, h);
            ctx.arcTo(leftW, h, leftW, h - r, r);
            ctx.lineTo(leftW, b + r);
            ctx.arcTo(leftW, b, leftW + r, b, r);

            ctx.lineTo(centerStart - r, b);
            ctx.arcTo(centerStart, b, centerStart, b + r, r);
            ctx.lineTo(centerStart, h - r);
            ctx.arcTo(centerStart, h, centerStart + r, h, r);
            ctx.lineTo(centerEnd - r, h);
            ctx.arcTo(centerEnd, h, centerEnd, h - r, r);
            ctx.lineTo(centerEnd, b + r);
            ctx.arcTo(centerEnd, b, centerEnd + r, b, r);

            ctx.lineTo(rightStart - r, b);
            ctx.arcTo(rightStart, b, rightStart, b + r, r);
            ctx.lineTo(rightStart, h - r);
            ctx.arcTo(rightStart, h, rightStart + r, h, r);
            ctx.lineTo(w, h);
        }

        ctx.beginPath();
        ctx.fillStyle = root.fill;
        traceInner();
        ctx.lineTo(w, 0);
        ctx.lineTo(0, 0);
        ctx.closePath();
        ctx.fill();

        // Only the edge facing the desktop. The screen top and side edges stay bare.
        if (root.strokeWidth > 0) {
            ctx.save();
            ctx.clip();
            ctx.beginPath();
            traceInner();
            ctx.lineWidth = root.strokeWidth * 2;
            ctx.strokeStyle = root.strokeColor;
            ctx.lineJoin = "round";
            ctx.lineCap = "butt";
            ctx.stroke();
            ctx.restore();
        }
    }
}
