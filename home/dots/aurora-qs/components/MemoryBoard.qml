import QtQuick

import "../core" as Core
import "../services" as Services

Rectangle {
    id: board

    radius: 16
    color: Core.Theme.surface
    border.color: Core.Theme.accent
    border.width: 1
    clip: true

    readonly property color ramColor: "#A6E3A1"
    readonly property color vramColor: "#89B4FA"
    readonly property color swapColor: "#F9E2AF"
    readonly property var rams: Services.SystemMonitor.memoryHistory
    readonly property var vrams: Services.SystemMonitor.vramHistory
    readonly property var swaps: Services.SystemMonitor.swapHistory
    readonly property bool showSwap: Services.SystemMonitor.swapEnabled
    property int hoverIndex: -1

    function pointCount() {
        return Math.max(rams.length, vrams.length, showSwap ? swaps.length : 0);
    }

    function indexAtX(x, width) {
        const count = pointCount();
        if (count < 1)
            return -1;
        if (count === 1)
            return 0;
        const ratio = Math.max(0, Math.min(1, x / Math.max(width, 1)));
        return Math.round(ratio * (count - 1));
    }

    Text {
        id: title
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        text: "󰍛  Memory"
        color: Core.Theme.foreground
        font.family: Core.Theme.fontFamily
        font.pixelSize: 10
        font.bold: true
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        text: "100%"
        color: Core.Theme.foregroundFaint
        font.family: Core.Theme.fontFamily
        font.pixelSize: 9
    }

    Item {
        id: graphArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: title.bottom
        anchors.bottom: legend.top
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 6

        Canvas {
            id: graph
            anchors.fill: parent

            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);

                const padTop = 4;
                const padBottom = 4;
                const chartHeight = height - padTop - padBottom;
                const rams = board.rams;
                const vrams = board.vrams;
                const swaps = board.swaps;
                const points = board.pointCount();
                if (points < 2) {
                    context.strokeStyle = Core.Theme.accent;
                    context.setLineDash([3, 3]);
                    context.strokeRect(0.5, 0.5, width - 1, height - 1);
                    context.setLineDash([]);
                    context.fillStyle = Core.Theme.foregroundFaint;
                    context.font = "9px \"" + Core.Theme.fontFamily + "\"";
                    context.fillText("Collecting samples…", 8, height / 2);
                    return;
                }

                const xAt = index => index * (width - 1) / (points - 1);
                const yAt = value => padTop + chartHeight - (Math.max(0, Math.min(100, value)) / 100) * chartHeight;

                context.strokeStyle = Core.Theme.separator;
                context.lineWidth = 1;
                context.setLineDash([2, 3]);
                context.strokeRect(0.5, 0.5, width - 1, height - 1);
                context.setLineDash([]);

                context.beginPath();
                context.moveTo(xAt(0), height - padBottom);
                for (let i = 0; i < rams.length; i++)
                    context.lineTo(xAt(i), yAt(rams[i]));
                context.lineTo(xAt(rams.length - 1), height - padBottom);
                context.closePath();
                context.fillStyle = "rgba(166, 227, 161, 0.30)";
                context.fill();

                function strokeSeries(values, color, widthPx) {
                    context.beginPath();
                    for (let i = 0; i < values.length; i++) {
                        const x = xAt(i);
                        const y = yAt(values[i]);
                        if (i === 0)
                            context.moveTo(x, y);
                        else
                            context.lineTo(x, y);
                    }
                    context.strokeStyle = color;
                    context.lineWidth = widthPx;
                    context.stroke();
                }

                strokeSeries(rams, board.ramColor, 1.5);
                strokeSeries(vrams, board.vramColor, 2);
                if (board.showSwap)
                    strokeSeries(swaps, board.swapColor, 1.5);

                if (board.hoverIndex >= 0 && board.hoverIndex < points) {
                    const hx = xAt(board.hoverIndex);
                    context.strokeStyle = "rgba(255, 255, 255, 0.7)";
                    context.lineWidth = 1;
                    context.setLineDash([3, 3]);
                    context.beginPath();
                    context.moveTo(hx, 0);
                    context.lineTo(hx, height);
                    context.stroke();
                    context.setLineDash([]);
                }
            }

            Connections {
                target: Services.SystemMonitor
                function onMemoryHistoryChanged() { graph.requestPaint(); }
                function onVramHistoryChanged() { graph.requestPaint(); }
                function onSwapHistoryChanged() { graph.requestPaint(); }
            }
            Connections {
                target: board
                function onHoverIndexChanged() { graph.requestPaint(); }
                function onShowSwapChanged() { graph.requestPaint(); }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.CrossCursor
            onPositionChanged: mouse => board.hoverIndex = board.indexAtX(mouse.x, width)
            onEntered: board.hoverIndex = board.indexAtX(mouseX, width)
            onExited: board.hoverIndex = -1
        }
    }

    Column {
        id: legend
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 10
        spacing: 8

        Column {
            width: parent.width
            spacing: 3

            Text {
                text: "RAM " + Services.SystemMonitor.memory + "% · " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramTotalBytes)
                color: Core.Theme.foreground
                font.family: Core.Theme.fontFamily
                font.pixelSize: 9
            }
            Text {
                text: "VRAM " + Services.SystemMonitor.vram + "% · " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.vramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.vramTotalBytes)
                color: Core.Theme.foreground
                font.family: Core.Theme.fontFamily
                font.pixelSize: 9
            }
            Text {
                visible: board.showSwap
                text: "SWAP " + Services.SystemMonitor.swap + "% · " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.swapUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.swapTotalBytes)
                color: Core.Theme.foreground
                font.family: Core.Theme.fontFamily
                font.pixelSize: 9
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Item {
                width: parent.width
                height: ssdLabel.implicitHeight

                Text {
                    id: ssdLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SSD  " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.diskUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.diskTotalBytes)
                    color: Core.Theme.foregroundFaint
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 9
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Services.SystemMonitor.disk + "%"
                    color: Core.Theme.foreground
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: Qt.rgba(Core.Theme.foreground.r, Core.Theme.foreground.g, Core.Theme.foreground.b, 0.12)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(0, Math.min(1, Services.SystemMonitor.disk / 100.0)) * parent.width
                    radius: parent.radius
                    color: Core.Theme.accent
                }
            }
        }
    }
}
