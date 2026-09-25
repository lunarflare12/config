import QtQuick
import QtQuick.Layouts

import "../core" as Core
import "../services" as Services

// Processor and memory cards on the shared grid.
Item {
    id: root

    property var modelData: null
    property var host: parent

    readonly property string monitorName: root.host && root.host.monitorName ? root.host.monitorName : ""
    readonly property bool onDesktop: Core.Session.isWidgetMonitor(root.monitorName)
    readonly property int span: 4

    anchors.fill: parent
    visible: root.onDesktop

    property bool counting: false

    function syncCount() {
        if (root.visible === root.counting)
            return;
        if (root.visible)
            Core.Session.desktopMetricsCount += 1;
        else if (Core.Session.desktopMetricsCount > 0)
            Core.Session.desktopMetricsCount -= 1;
        root.counting = root.visible;
    }

    onVisibleChanged: root.syncCount()
    Component.onCompleted: root.syncCount()
    Component.onDestruction: {
        if (root.counting && Core.Session.desktopMetricsCount > 0)
            Core.Session.desktopMetricsCount -= 1;
    }

    DesktopWidget {
        host: root.host
        widgetId: "processor"
        onDesktop: root.onDesktop
        spanW: 4
        spanH: 3
        defaultCol: Math.max(0, (root.host ? root.host.cols : 12) - root.span * 2)
        defaultRow: Math.max(0, (root.host ? root.host.rows : 8) - 3)
        contentComponent: processorContent
    }

    DesktopWidget {
        host: root.host
        widgetId: "memory"
        onDesktop: root.onDesktop
        spanW: 4
        spanH: 4
        defaultCol: Math.max(0, (root.host ? root.host.cols : 12) - root.span)
        defaultRow: Math.max(0, (root.host ? root.host.rows : 8) - 4)
        contentComponent: memoryContent
    }

    Component {
        id: processorContent

        ColumnLayout {
            anchors.fill: parent
            spacing: Core.Theme.spacing

            PercentBoard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 48
                icon: "cpu"
                title: Services.SystemMonitor.cpuName !== "" ? Services.SystemMonitor.cpuName : "CPU"
                seriesColor: "#CBA6F7"
                values: Services.SystemMonitor.cpuHistory
                currentValue: Services.SystemMonitor.cpu
                detailText: Services.SystemMonitor.temperature < 0 ? "--" : Services.SystemMonitor.temperature + "°C"
            }

            PercentBoard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 48
                icon: "gpu"
                title: Services.SystemMonitor.gpuName !== "" ? Services.SystemMonitor.gpuName : "GPU"
                seriesColor: "#89B4FA"
                values: Services.SystemMonitor.gpuHistory
                currentValue: Services.SystemMonitor.gpu
                detailText: Services.SystemMonitor.gpuTemperature < 0 ? "--" : Services.SystemMonitor.gpuTemperature + "°C"
            }
        }
    }

    Component {
        id: memoryContent

        ColumnLayout {
            anchors.fill: parent
            spacing: Core.Theme.spacing

            DiskBar {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                icon: "ram"
                barColor: "#A6E3A1"
                label: "RAM"
                usedBytes: Services.SystemMonitor.ramUsedBytes
                totalBytes: Services.SystemMonitor.ramTotalBytes
            }

            DiskBar {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                icon: "gpu"
                barColor: "#89B4FA"
                label: "VRAM"
                usedBytes: Services.SystemMonitor.vramUsedBytes
                totalBytes: Services.SystemMonitor.vramTotalBytes
            }

            DiskBar {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                icon: "swap"
                barColor: "#F9E2AF"
                label: "SWAP"
                usedBytes: Services.SystemMonitor.swapUsedBytes
                totalBytes: Services.SystemMonitor.swapTotalBytes
            }

            DiskBar {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                label: "/"
                usedBytes: Services.SystemMonitor.diskUsedBytes
                totalBytes: Services.SystemMonitor.diskTotalBytes
            }

            DiskBar {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                label: "/home"
                usedBytes: Services.SystemMonitor.homeDiskUsedBytes
                totalBytes: Services.SystemMonitor.homeDiskTotalBytes
            }
        }
    }
}
