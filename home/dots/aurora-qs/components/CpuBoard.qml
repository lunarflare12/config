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

    readonly property color cpuColor: "#CBA6F7"
    readonly property color gpuColor: "#89B4FA"
    readonly property var cpus: Services.SystemMonitor.cpuHistory
    readonly property var gpus: Services.SystemMonitor.gpuHistory
    readonly property var timestamps: Services.SystemMonitor.cpuTimestamps
    property int hoverIndex: -1

    function formatClock(ms) {
        if (!ms)
            return "--:--:--";
        const date = new Date(ms);
        const pad = value => String(value).padStart(2, "0");
        return pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds());
    }

    function pointCount() {
        return Math.max(cpus.length, gpus.length);
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
        text: "󰻠  Processor"
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
                const cpus = board.cpus;
                const gpus = board.gpus;
                const points = Math.max(cpus.length, gpus.length);
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
                context.beginPath();
                context.moveTo(0, padTop + 0.5);
                context.lineTo(width, padTop + 0.5);
                context.stroke();
                context.setLineDash([]);

                context.beginPath();
                context.moveTo(xAt(0), height - padBottom);
                for (let i = 0; i < cpus.length; i++)
                    context.lineTo(xAt(i), yAt(cpus[i]));
                context.lineTo(xAt(cpus.length - 1), height - padBottom);
                context.closePath();
                context.fillStyle = "rgba(203, 166, 247, 0.45)";
                context.fill();

                context.beginPath();
                for (let i = 0; i < cpus.length; i++) {
                    const x = xAt(i);
                    const y = yAt(cpus[i]);
                    if (i === 0)
                        context.moveTo(x, y);
                    else
                        context.lineTo(x, y);
                }
                context.strokeStyle = board.cpuColor;
                context.lineWidth = 1.5;
                context.stroke();

                context.beginPath();
                for (let i = 0; i < gpus.length; i++) {
                    const x = xAt(i);
                    const y = yAt(gpus[i]);
                    if (i === 0)
                        context.moveTo(x, y);
                    else
                        context.lineTo(x, y);
                }
                context.strokeStyle = board.gpuColor;
                context.lineWidth = 2;
                context.stroke();

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

                    const cy = yAt(cpus[board.hoverIndex] || 0);
                    const gy = yAt(gpus[board.hoverIndex] || 0);

                    context.fillStyle = board.cpuColor;
                    context.beginPath();
                    context.arc(hx, cy, 4, 0, Math.PI * 2);
                    context.fill();
                    context.strokeStyle = "#FFFFFF";
                    context.lineWidth = 1.5;
                    context.stroke();

                    context.fillStyle = board.gpuColor;
                    context.beginPath();
                    context.arc(hx, gy, 4, 0, Math.PI * 2);
                    context.fill();
                    context.strokeStyle = "#FFFFFF";
                    context.lineWidth = 1.5;
                    context.stroke();
                }
            }

            Connections {
                target: Services.SystemMonitor
                function onCpuHistoryChanged() { graph.requestPaint(); }
                function onGpuHistoryChanged() { graph.requestPaint(); }
            }
            Connections {
                target: board
                function onHoverIndexChanged() { graph.requestPaint(); }
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

        Rectangle {
            id: tooltip
            visible: board.hoverIndex >= 0 && board.pointCount() > 0
            width: tipColumn.implicitWidth + 16
            height: tipColumn.implicitHeight + 12
            radius: 8
            color: "#2A2A2E"
            border.color: "#3D3D42"
            border.width: 1
            z: 10

            readonly property real markerX: {
                const count = board.pointCount();
                if (count < 2)
                    return graphArea.width / 2;
                return board.hoverIndex * (graphArea.width - 1) / (count - 1);
            }

            x: {
                const preferred = markerX + 12;
                if (preferred + width > graphArea.width)
                    return Math.max(0, markerX - width - 12);
                return preferred;
            }
            y: 6

            Column {
                id: tipColumn
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: board.formatClock(board.timestamps[board.hoverIndex] || 0)
                    color: "#A0A0A5"
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 9
                }

                Row {
                    spacing: 6
                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: board.cpuColor
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "󰻠"
                            color: "white"
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
                    Text {
                        text: (board.cpus[board.hoverIndex] || 0) + "%  ·  " + (Services.SystemMonitor.temperature < 0 ? "--" : Services.SystemMonitor.temperature + "°C")
                        color: "white"
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 6
                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: board.gpuColor
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "󰢮"
                            color: "white"
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
                    Text {
                        text: (board.gpus[board.hoverIndex] || 0) + "%  ·  " + (Services.SystemMonitor.gpuTemperature < 0 ? "--" : Services.SystemMonitor.gpuTemperature + "°C")
                        color: "white"
                        font.family: Core.Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    Item {
        id: legend
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 10
        height: 28

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: board.formatClock(timestamps.length ? timestamps[0] : 0)
            color: Core.Theme.foregroundFaint
            font.family: Core.Theme.fontFamily
            font.pixelSize: 8
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: board.formatClock(timestamps.length ? timestamps[timestamps.length - 1] : 0)
            color: Core.Theme.foregroundFaint
            font.family: Core.Theme.fontFamily
            font.pixelSize: 8
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 14

            Row {
                spacing: 6
                Rectangle { width: 8; height: 8; radius: 4; color: board.cpuColor; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "CPU: " + Services.SystemMonitor.cpu + "% · " + (Services.SystemMonitor.temperature < 0 ? "--" : Services.SystemMonitor.temperature + "°C")
                    color: Core.Theme.foreground
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: 6
                Rectangle { width: 8; height: 8; radius: 4; color: board.gpuColor; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "GPU: " + Services.SystemMonitor.gpu + "% · " + (Services.SystemMonitor.gpuTemperature < 0 ? "--" : Services.SystemMonitor.gpuTemperature + "°C")
                    color: Core.Theme.foreground
                    font.family: Core.Theme.fontFamily
                    font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
