import QtQuick
import QtQuick.Layouts
import Quickshell

import "../core" as Core
import "../services" as Services

// Three desktop cards on the shared grid.
Item {
    id: root

    property var modelData: null
    property var host: parent

    readonly property string monitorName: root.host && root.host.monitorName ? root.host.monitorName : ""
    readonly property bool onDesktop: Core.Session.isDesktopMonitor(root.monitorName)
    readonly property int span: 3

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
        widgetId: "network"
        onDesktop: root.onDesktop
        spanW: 3
        spanH: 3
        defaultCol: Math.max(0, (root.host ? root.host.cols : 12) - root.span * 3)
        defaultRow: Math.max(0, (root.host ? root.host.rows : 8) - 3)
        contentComponent: networkContent
    }

    DesktopWidget {
        host: root.host
        widgetId: "processor"
        onDesktop: root.onDesktop
        spanW: 3
        spanH: 3
        defaultCol: Math.max(0, (root.host ? root.host.cols : 12) - root.span * 2)
        defaultRow: Math.max(0, (root.host ? root.host.rows : 8) - 3)
        contentComponent: processorContent
    }

    DesktopWidget {
        host: root.host
        widgetId: "memory"
        onDesktop: root.onDesktop
        spanW: 3
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

            PopupHeader {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                title: "Processor"
                subtitle: {
                    const cpu = Services.SystemMonitor.cpu + "%";
                    const temp = Services.SystemMonitor.temperature < 0 ? "--" : Services.SystemMonitor.temperature + "°C";
                    const gpu = Services.SystemMonitor.gpu + "%";
                    const gtemp = Services.SystemMonitor.gpuTemperature < 0 ? "--" : Services.SystemMonitor.gpuTemperature + "°C";
                    return "CPU " + cpu + " · " + temp + "  ·  GPU " + gpu + " · " + gtemp;
                }
                showToggle: false
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Core.Theme.separator
            }

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

            PopupHeader {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                title: "Memory"
                subtitle: Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramTotalBytes)
                showToggle: false
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Core.Theme.separator
            }

            PercentBoard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 48
                icon: "ram"
                title: "RAM"
                seriesColor: "#A6E3A1"
                values: Services.SystemMonitor.memoryHistory
                currentValue: Services.SystemMonitor.memory
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramTotalBytes)
            }

            PercentBoard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 48
                icon: "gpu"
                title: "VRAM"
                seriesColor: "#89B4FA"
                values: Services.SystemMonitor.vramHistory
                currentValue: Services.SystemMonitor.vram
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.vramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.vramTotalBytes)
            }

            PercentBoard {
                visible: Services.SystemMonitor.swapEnabled
                Layout.fillWidth: true
                Layout.fillHeight: Services.SystemMonitor.swapEnabled
                Layout.preferredHeight: Services.SystemMonitor.swapEnabled ? -1 : 0
                Layout.minimumHeight: Services.SystemMonitor.swapEnabled ? 48 : 0
                icon: "swap"
                title: "SWAP"
                seriesColor: "#F9E2AF"
                values: Services.SystemMonitor.swapHistory
                currentValue: Services.SystemMonitor.swap
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.swapUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.swapTotalBytes)
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

    Component {
        id: networkContent

        ColumnLayout {
            anchors.fill: parent
            spacing: Core.Theme.spacing

            PopupHeader {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                title: "Ethernet"
                subtitle: Services.NetworkService.linkLabel
                showToggle: false
                actions: [
                    {
                        icon: Core.Icons.gear,
                        action: function () {
                            Services.NetworkService.openEditor();
                        }
                    }
                ]
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Core.Theme.separator
            }

            ListRow {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                iconName: "ethernet"
                title: Services.NetworkService.ethConnection !== "" ? Services.NetworkService.ethConnection : "Wired"
                subtitle: {
                    const svc = Services.NetworkService;
                    if (svc.ethConnected) {
                        const parts = ["Connected"];
                        if (svc.ethIp !== "")
                            parts.push(svc.ethIp);
                        if (svc.ethDevice !== "")
                            parts.push(svc.ethDevice);
                        return parts.join(" · ");
                    }
                    if (svc.ethState === "unavailable")
                        return "Cable unplugged";
                    return svc.ethAvailable ? "Disconnected" : "No ethernet adapter";
                }
                trailingName: Services.NetworkService.ethConnected ? "check" : ""
                trailing: ""
                trailingColor: Core.Theme.success
                active: Services.NetworkService.ethConnected
                dimmed: !Services.NetworkService.ethAvailable
                onActivated: Services.NetworkService.toggleEthernet()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Core.Theme.separator
            }

            NetworkBoard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 56
            }
        }
    }
}
