pragma Singleton

import QtQuick

import "../core" as Core

// Shared desktop snap grid. Icons and widgets both occupy cells.
QtObject {
    id: root

    readonly property int cellW: 96
    readonly property int cellH: 108
    readonly property int originX: 16 + Core.Theme.dockReserve
    readonly property int originY: Core.Theme.barHeight + 12
    readonly property int bottomPad: 16
    readonly property int rightPad: 16

    function colsFor(width) {
        return Math.max(1, Math.floor((Math.max(width, 1) - root.originX - root.rightPad) / root.cellW));
    }

    function rowsFor(height) {
        return Math.max(1, Math.floor((Math.max(height, 1) - root.originY - root.bottomPad) / root.cellH));
    }

    function posX(col) {
        return root.originX + col * root.cellW;
    }

    function posY(row) {
        return root.originY + row * root.cellH;
    }

    function colAt(x) {
        return Math.round((x - root.originX) / root.cellW);
    }

    function rowAt(y) {
        return Math.round((y - root.originY) / root.cellH);
    }

    function spanW(width) {
        return Math.max(1, Math.ceil(Math.max(width, 1) / root.cellW));
    }

    function spanH(height) {
        return Math.max(1, Math.ceil(Math.max(height, 1) / root.cellH));
    }

    function clampCol(col, span, cols) {
        return Math.max(0, Math.min(Math.max(0, cols - span), col));
    }

    function clampRow(row, span, rows) {
        return Math.max(0, Math.min(Math.max(0, rows - span), row));
    }
}
