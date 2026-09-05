import QtQuick

import "../core" as Core
import "../services" as Services

Rectangle {
    id: board

    property string title: "Metric"
    property color seriesColor: Core.Theme.accent
    property var values: []
    property int currentValue: 0
    property string detailText: ""
    property int hoverIndex: -1

    radius: 16
    color: Core.Theme.surface
    border.color: Core.Theme.accent
    border.width: 1
    clip: true

    function indexAtX(x, width) {
        const count = values.length;
        if (count < 1)
            return -1;
        if (count === 1)
            return 0;
        const ratio = Math.max(0, Math.min(1, x / Math.max(width, 1)));
        return Math.round(ratio * (count - 1));
    }

    Text {
        id: titleLabel
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        text: board.title
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
        anchors.top: titleLabel.bottom
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
                const values = board.values;
                if (values.length < 2) {
                    context.strokeStyle = Core.Theme.accent;
                    context.setLineDash([3, 3]);
                    context.strokeRect(0.5, 0.5, width - 1, height - 1);
                    context.setLineDash([]);
                    context.fillStyle = Core.Theme.foregroundFaint;
                    context.font = "9px \"" + Core.Theme.fontFamily + "\"";
                    context.fillText("Collecting samples…", 8, height / 2);
                    return;
                }

                const xAt = index => index * (width - 1) / (values.length - 1);
                const yAt = value => padTop + chartHeight - (Math.max(0, Math.min(100, value)) / 100) * chartHeight;
                const c = board.seriesColor;

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
                for (let i = 0; i < values.length; i++)
                    context.lineTo(xAt(i), yAt(values[i]));
                context.lineTo(xAt(values.length - 1), height - padBottom);
                context.closePath();
                context.fillStyle = "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", " + Math.round(c.b * 255) + ", 0.40)";
                context.fill();

                context.beginPath();
                for (let i = 0; i < values.length; i++) {
                    const x = xAt(i);
                    const y = yAt(values[i]);
                    if (i === 0)
                        context.moveTo(x, y);
                    else
                        context.lineTo(x, y);
                }
                context.strokeStyle = board.seriesColor;
                context.lineWidth = 1.5;
                context.stroke();

                if (board.hoverIndex >= 0 && board.hoverIndex < values.length) {
                    const hx = xAt(board.hoverIndex);
                    const hy = yAt(values[board.hoverIndex]);
                    context.strokeStyle = "rgba(255, 255, 255, 0.7)";
                    context.lineWidth = 1;
                    context.setLineDash([3, 3]);
                    context.beginPath();
                    context.moveTo(hx, 0);
                    context.lineTo(hx, height);
                    context.stroke();
                    context.setLineDash([]);

                    context.fillStyle = board.seriesColor;
                    context.beginPath();
                    context.arc(hx, hy, 4, 0, Math.PI * 2);
                    context.fill();
                    context.strokeStyle = "#FFFFFF";
                    context.lineWidth = 1.5;
                    context.stroke();
                }
            }

            Connections {
                target: board
                function onValuesChanged() { graph.requestPaint(); }
                function onHoverIndexChanged() { graph.requestPaint(); }
                function onSeriesColorChanged() { graph.requestPaint(); }
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
            visible: board.hoverIndex >= 0 && board.values.length > 0
            width: tipText.implicitWidth + 16
            height: tipText.implicitHeight + 12
            radius: 8
            color: "#2A2A2E"
            border.color: "#3D3D42"
            border.width: 1
            z: 10

            readonly property real markerX: {
                const count = board.values.length;
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

            Text {
                id: tipText
                anchors.centerIn: parent
                text: (board.values[board.hoverIndex] || 0) + "%"
                color: "white"
                font.family: Core.Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
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
        height: 18

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: board.seriesColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: board.currentValue + "%" + (board.detailText !== "" ? "  ·  " + board.detailText : "")
                color: Core.Theme.foreground
                font.family: Core.Theme.fontFamily
                font.pixelSize: 9
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
