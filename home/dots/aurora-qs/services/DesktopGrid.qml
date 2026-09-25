pragma Singleton

import QtQuick

import "../core" as Core

// Shared desktop snap grid. Icons and widgets both occupy cells.
// Cells grow to fill the monitor; only a few pixels of padding stay around the edges.
QtObject {
    id: root

    readonly property int minCell: 90
    // Dock already takes exclusive zone; adding dockReserve here left a dead column.
    readonly property int originX: 4
    // Desktop layer already sits below the bar exclusive zone.
    readonly property int originY: 4
    readonly property int bottomPad: 4
    readonly property int rightPad: 4
    readonly property int gap: 8

    readonly property int cellW: 96
    readonly property int cellH: 96

    function colsFor(width) {
        const avail = Math.max(1, Math.max(width, 1) - root.originX - root.rightPad);
        return Math.max(1, Math.floor(avail / root.minCell));
    }

    function rowsFor(height) {
        const avail = Math.max(1, Math.max(height, 1) - root.originY - root.bottomPad);
        return Math.max(1, Math.floor(avail / root.minCell));
    }

    function cellWFor(width) {
        const avail = Math.max(1, Math.max(width, 1) - root.originX - root.rightPad);
        return Math.max(root.minCell, Math.floor(avail / root.colsFor(width)));
    }

    function cellHFor(height) {
        const avail = Math.max(1, Math.max(height, 1) - root.originY - root.bottomPad);
        return Math.max(root.minCell, Math.floor(avail / root.rowsFor(height)));
    }

    function posX(col, cellW) {
        const w = cellW > 0 ? cellW : root.cellW;
        return root.originX + col * w;
    }

    function posY(row, cellH) {
        const h = cellH > 0 ? cellH : root.cellH;
        return root.originY + row * h;
    }

    function colAt(x, cellW) {
        const w = cellW > 0 ? cellW : root.cellW;
        return Math.round((x - root.originX) / w);
    }

    function rowAt(y, cellH) {
        const h = cellH > 0 ? cellH : root.cellH;
        return Math.round((y - root.originY) / h);
    }

    function spanW(width, cellW) {
        const w = cellW > 0 ? cellW : root.cellW;
        return Math.max(1, Math.ceil(Math.max(width, 1) / w));
    }

    function spanH(height, cellH) {
        const h = cellH > 0 ? cellH : root.cellH;
        return Math.max(1, Math.ceil(Math.max(height, 1) / h));
    }

    function clampCol(col, span, cols) {
        return Math.max(0, Math.min(Math.max(0, cols - span), col));
    }

    function clampRow(row, span, rows) {
        return Math.max(0, Math.min(Math.max(0, rows - span), row));
    }
}
