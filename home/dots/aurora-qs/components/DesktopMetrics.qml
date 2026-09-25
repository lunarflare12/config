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
        fitHeight: true
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
                seriesColor: Core.Theme.accent
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
                seriesColor: Core.Theme.info
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
            spacing: 8

            implicitHeight: {
                const n = bars.length;
                return n < 1 ? 0 : n * 52 + (n - 1) * spacing;
            }

            readonly property var bars: {
                const m = Services.SystemMonitor;
                const rows = [];
                if (m.ramTotalBytes > 0)
                    rows.push({ icon: "ram", color: Core.Theme.success, label: "RAM", used: m.ramUsedBytes, total: m.ramTotalBytes });
                if (m.vramTotalBytes > 0)
                    rows.push({ icon: "gpu", color: Core.Theme.info, label: "VRAM", used: m.vramUsedBytes, total: m.vramTotalBytes });
                if (m.swapTotalBytes > 0)
                    rows.push({ icon: "swap", color: "#F9E2AF", label: "SWAP", used: m.swapUsedBytes, total: m.swapTotalBytes });
                if (m.diskTotalBytes > 0)
                    rows.push({ icon: "disk", color: Core.Theme.accent, label: "/", used: m.diskUsedBytes, total: m.diskTotalBytes });
                if (m.homeDiskTotalBytes > 0)
                    rows.push({ icon: "disk", color: Core.Theme.accent, label: "/home", used: m.homeDiskUsedBytes, total: m.homeDiskTotalBytes });
                return rows;
            }

            Repeater {
                model: parent.bars

                DiskBar {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    icon: modelData.icon
                    barColor: modelData.color
                    label: modelData.label
                    usedBytes: modelData.used
                    totalBytes: modelData.total
                }
            }
        }
    }
}
