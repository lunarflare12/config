import QtQuick

import "../core" as Core
import "../services" as Services

Rectangle {
    id: board

    property string icon: ""
    property string title: "Metric"
    property color seriesColor: Core.Theme.accent
    property var values: []
    property int currentValue: 0
    property string detailText: ""
    property int hoverIndex: -1

    radius: 0
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

    Item {
        id: titleRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 12
        anchors.rightMargin: 48
        anchors.topMargin: 10
        height: 18

        MetricIcon {
            id: iconLabel

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            visible: board.icon !== ""
            width: visible ? 16 : 0
            height: 16

            name: board.icon
            color: board.seriesColor
        }

        Text {
            id: titleLabel

            anchors.left: iconLabel.right
            anchors.leftMargin: iconLabel.visible ? 6 : 0
            anchors.verticalCenter: parent.verticalCenter

            width: Math.max(0, parent.width - iconLabel.width - (iconLabel.visible ? 6 : 0))
            text: board.title
            elide: Text.ElideRight
            color: Core.Theme.foreground

            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            font.weight: Font.DemiBold

            renderType: Text.QtRendering
        }
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        text: "100%"
        color: Core.Theme.foregroundFaint
        font.family: Core.Theme.fontFamily
        font.pixelSize: Core.Theme.fontSizeSmall
        renderType: Text.NativeRendering
    }

    Item {
        id: graphArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleRow.bottom
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
                const values = board.values.length >= 2 ? board.values : [board.currentValue, board.currentValue];

                const xAt = index => index * (width - 1) / (values.length - 1);
                const yAt = value => padTop + chartHeight - (Math.max(0, Math.min(100, value)) / 100) * chartHeight;
                const c = board.seriesColor;
                const cr = Math.round(c.r * 255);
                const cg = Math.round(c.g * 255);
                const cb = Math.round(c.b * 255);

                const step = 7;
                context.fillStyle = "rgba(255, 255, 255, 0.16)";
                for (let y = padTop; y <= height - padBottom; y += step) {
                    for (let x = 1; x <= width - 1; x += step) {
                        context.fillRect(x, y, 1.25, 1.25);
                    }
                }

                context.beginPath();
                context.moveTo(xAt(0), height - padBottom);
                for (let i = 0; i < values.length; i++)
                    context.lineTo(xAt(i), yAt(values[i]));
                context.lineTo(xAt(values.length - 1), height - padBottom);
                context.closePath();
                context.fillStyle = "rgba(" + cr + ", " + cg + ", " + cb + ", 0.16)";
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
                function onCurrentValueChanged() { graph.requestPaint(); }
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
                font.pixelSize: Core.Theme.fontSizeSmall
                font.bold: true
                renderType: Text.NativeRendering
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
                font.pixelSize: Core.Theme.fontSizeSmall
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
