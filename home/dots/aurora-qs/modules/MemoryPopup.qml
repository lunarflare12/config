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

            Components.DiskBar {
                width: parent.width
                icon: "ram"
                barColor: "#A6E3A1"
                label: "RAM"
                usedBytes: Services.SystemMonitor.ramUsedBytes
                totalBytes: Services.SystemMonitor.ramTotalBytes
            }

            Components.DiskBar {
                width: parent.width
                icon: "gpu"
                barColor: "#89B4FA"
                label: "VRAM"
                usedBytes: Services.SystemMonitor.vramUsedBytes
                totalBytes: Services.SystemMonitor.vramTotalBytes
            }

            Components.DiskBar {
                width: parent.width
                icon: "swap"
                barColor: "#F9E2AF"
                label: "SWAP"
                usedBytes: Services.SystemMonitor.swapUsedBytes
                totalBytes: Services.SystemMonitor.swapTotalBytes
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
