import QtQuick
import "../Singletons" as Local

Rectangle {
    id: board

    radius: 16
    color: Local.Theme.surface
    border.color: Local.Theme.accent
    border.width: 1
    clip: true

    readonly property color downloadColor: "#62A0EA"
    readonly property color uploadColor: "#33D17A"
    readonly property var downloads: Local.SystemMonitor.downloadHistory
    readonly property var uploads: Local.SystemMonitor.uploadHistory
    readonly property var timestamps: Local.SystemMonitor.networkTimestamps
    property int hoverIndex: -1
    readonly property real maxMbit: {
        let maximum = 1
        for (let i = 0; i < downloads.length; i++)
            maximum = Math.max(maximum, Local.SystemMonitor.toMbit(downloads[i]), Local.SystemMonitor.toMbit(uploads[i] || 0))
        if (maximum <= 1)
            return 1
        if (maximum <= 5)
            return 5
        if (maximum <= 10)
            return 10
        if (maximum <= 25)
            return 25
        if (maximum <= 50)
            return 50
        if (maximum <= 100)
            return 100
        if (maximum <= 200)
            return 200
        if (maximum <= 500)
            return 500
        if (maximum <= 1000)
            return 1000
        return Math.ceil(maximum / 100) * 100
    }

    function formatClock(ms) {
        if (!ms)
            return "--:--:--"
        const date = new Date(ms)
        const pad = value => String(value).padStart(2, "0")
        return pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds())
    }

    function pointCount() {
        return Math.max(downloads.length, uploads.length)
    }

    function indexAtX(x, width) {
        const count = pointCount()
        if (count < 1)
            return -1
        if (count === 1)
            return 0
        const ratio = Math.max(0, Math.min(1, x / Math.max(width, 1)))
        return Math.round(ratio * (count - 1))
    }

    function yForKib(kib, height) {
        const padTop = 4
        const padBottom = 4
        const chartHeight = height - padTop - padBottom
        const maxValue = Math.max(board.maxMbit, 0.001)
        return padTop + chartHeight - (Local.SystemMonitor.toMbit(kib) / maxValue) * chartHeight
    }

    Text {
        id: title
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 12
        text: "󰈀  Network"
        color: Local.Theme.text
        font.family: Local.Theme.font
        font.pixelSize: 10
        font.bold: true
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        text: board.maxMbit + " Mbit/s"
        color: Local.Theme.muted
        font.family: Local.Theme.font
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
                const context = getContext("2d")
                context.clearRect(0, 0, width, height)

                const padTop = 4
                const padBottom = 4
                const chartHeight = height - padTop - padBottom
                const downloads = board.downloads
                const uploads = board.uploads
                const points = Math.max(downloads.length, uploads.length)
                if (points < 2) {
                    context.strokeStyle = Local.Theme.accent
                    context.setLineDash([3, 3])
                    context.strokeRect(0.5, 0.5, width - 1, height - 1)
                    context.setLineDash([])
                    context.fillStyle = Local.Theme.muted
                    context.font = "9px \"" + Local.Theme.font + "\""
                    context.fillText("Collecting traffic…", 8, height / 2)
                    return
                }

                const maxValue = Math.max(board.maxMbit, 0.001)
                const xAt = index => index * (width - 1) / (points - 1)
                const yAt = kib => padTop + chartHeight - (Local.SystemMonitor.toMbit(kib) / maxValue) * chartHeight

                context.strokeStyle = Local.Theme.subtleMuted
                context.lineWidth = 1
                context.setLineDash([2, 3])
                context.strokeRect(0.5, 0.5, width - 1, height - 1)
                context.beginPath()
                context.moveTo(0, padTop + 0.5)
                context.lineTo(width, padTop + 0.5)
                context.stroke()
                context.setLineDash([])

                context.beginPath()
                context.moveTo(xAt(0), height - padBottom)
                for (let i = 0; i < downloads.length; i++)
                    context.lineTo(xAt(i), yAt(downloads[i]))
                context.lineTo(xAt(downloads.length - 1), height - padBottom)
                context.closePath()
                context.fillStyle = "rgba(98, 160, 234, 0.45)"
                context.fill()

                context.beginPath()
                for (let i = 0; i < downloads.length; i++) {
                    const x = xAt(i)
                    const y = yAt(downloads[i])
                    if (i === 0)
                        context.moveTo(x, y)
                    else
                        context.lineTo(x, y)
                }
                context.strokeStyle = board.downloadColor
                context.lineWidth = 1.5
                context.stroke()

                context.beginPath()
                for (let i = 0; i < uploads.length; i++) {
                    const x = xAt(i)
                    const y = yAt(uploads[i])
                    if (i === 0)
                        context.moveTo(x, y)
                    else
                        context.lineTo(x, y)
                }
                context.strokeStyle = board.uploadColor
                context.lineWidth = 2
                context.stroke()

                if (board.hoverIndex >= 0 && board.hoverIndex < points) {
                    const hx = xAt(board.hoverIndex)
                    context.strokeStyle = "rgba(255, 255, 255, 0.7)"
                    context.lineWidth = 1
                    context.setLineDash([3, 3])
                    context.beginPath()
                    context.moveTo(hx, 0)
                    context.lineTo(hx, height)
                    context.stroke()
                    context.setLineDash([])

                    const dy = yAt(downloads[board.hoverIndex] || 0)
                    const uy = yAt(uploads[board.hoverIndex] || 0)

                    context.fillStyle = board.downloadColor
                    context.beginPath()
                    context.arc(hx, dy, 4, 0, Math.PI * 2)
                    context.fill()
                    context.strokeStyle = "#FFFFFF"
                    context.lineWidth = 1.5
                    context.stroke()

                    context.fillStyle = board.uploadColor
                    context.beginPath()
                    context.arc(hx, uy, 4, 0, Math.PI * 2)
                    context.fill()
                    context.strokeStyle = "#FFFFFF"
                    context.lineWidth = 1.5
                    context.stroke()
                }
            }

            Connections {
                target: Local.SystemMonitor
                function onDownloadHistoryChanged() { graph.requestPaint() }
                function onUploadHistoryChanged() { graph.requestPaint() }
            }

            Connections {
                target: board
                function onHoverIndexChanged() { graph.requestPaint() }
                function onMaxMbitChanged() { graph.requestPaint() }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.CrossCursor

            onPositionChanged: mouse => {
                board.hoverIndex = board.indexAtX(mouse.x, width)
            }
            onEntered: {
                board.hoverIndex = board.indexAtX(mouseX, width)
            }
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
                const count = board.pointCount()
                if (count < 2)
                    return graphArea.width / 2
                return board.hoverIndex * (graphArea.width - 1) / (count - 1)
            }

            x: {
                const preferred = markerX + 12
                if (preferred + width > graphArea.width)
                    return Math.max(0, markerX - width - 12)
                return preferred
            }
            y: 6

            Column {
                id: tipColumn
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: board.formatClock(board.timestamps[board.hoverIndex] || 0)
                    color: "#A0A0A5"
                    font.family: Local.Theme.font
                    font.pixelSize: 9
                }

                Row {
                    spacing: 6
                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: board.downloadColor
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "󰁅"
                            color: "white"
                            font.family: Local.Theme.font
                            font.pixelSize: 9
                        }
                    }
                    Text {
                        text: Local.SystemMonitor.formatMbit(board.downloads[board.hoverIndex] || 0)
                        color: "white"
                        font.family: Local.Theme.font
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
                        color: board.uploadColor
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "󰁝"
                            color: "white"
                            font.family: Local.Theme.font
                            font.pixelSize: 9
                        }
                    }
                    Text {
                        text: Local.SystemMonitor.formatMbit(board.uploads[board.hoverIndex] || 0)
                        color: "white"
                        font.family: Local.Theme.font
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
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 8
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: board.formatClock(timestamps.length ? timestamps[timestamps.length - 1] : 0)
            color: Local.Theme.muted
            font.family: Local.Theme.font
            font.pixelSize: 8
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 14

            Row {
                spacing: 6
                Rectangle { width: 8; height: 8; radius: 4; color: board.downloadColor; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "Download: " + Local.SystemMonitor.formatMbit(Local.SystemMonitor.download)
                    color: Local.Theme.text
                    font.family: Local.Theme.font
                    font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                spacing: 6
                Rectangle { width: 8; height: 8; radius: 4; color: board.uploadColor; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "Upload: " + Local.SystemMonitor.formatMbit(Local.SystemMonitor.upload)
                    color: Local.Theme.text
                    font.family: Local.Theme.font
                    font.pixelSize: 9
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
