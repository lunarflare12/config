import QtQuick

import "../core" as Core
import "../services" as Services
import "../components" as Components

Components.PopupSurface {
    id: popup

    popupId: "memory"
    cardWidth: 360
    maxCardHeight: 620

    contentComponent: Component {
        Column {
            spacing: Core.Theme.spacing

            Components.PopupHeader {
                width: parent.width
                title: "Memory"
                subtitle: {
                    const ram = Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramTotalBytes);
                    return ram;
                }
                showToggle: false
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Core.Theme.separator
            }

            Components.PercentBoard {
                width: parent.width
                height: 120
                icon: "ram"
                title: "RAM"
                seriesColor: "#A6E3A1"
                values: Services.SystemMonitor.memoryHistory
                currentValue: Services.SystemMonitor.memory
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramTotalBytes)
            }

            Components.PercentBoard {
                width: parent.width
                height: 120
                icon: "gpu"
                title: "VRAM"
                seriesColor: "#89B4FA"
                values: Services.SystemMonitor.vramHistory
                currentValue: Services.SystemMonitor.vram
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.vramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.vramTotalBytes)
            }

            Components.PercentBoard {
                visible: Services.SystemMonitor.swapEnabled
                width: parent.width
                height: Services.SystemMonitor.swapEnabled ? 120 : 0
                icon: "swap"
                title: "SWAP"
                seriesColor: "#F9E2AF"
                values: Services.SystemMonitor.swapHistory
                currentValue: Services.SystemMonitor.swap
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.swapUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.swapTotalBytes)
            }

            Components.DiskBar {
                width: parent.width
                label: "/"
                usedBytes: Services.SystemMonitor.diskUsedBytes
                totalBytes: Services.SystemMonitor.diskTotalBytes
            }

            Components.DiskBar {
                width: parent.width
                label: "/home"
                usedBytes: Services.SystemMonitor.homeDiskUsedBytes
                totalBytes: Services.SystemMonitor.homeDiskTotalBytes
            }
        }
    }
}
