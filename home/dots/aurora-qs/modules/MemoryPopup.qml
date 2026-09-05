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
                title: "󰍛  RAM"
                seriesColor: "#A6E3A1"
                values: Services.SystemMonitor.memoryHistory
                currentValue: Services.SystemMonitor.memory
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.ramTotalBytes)
            }

            Components.PercentBoard {
                width: parent.width
                height: 120
                title: "󰢮  VRAM"
                seriesColor: "#89B4FA"
                values: Services.SystemMonitor.vramHistory
                currentValue: Services.SystemMonitor.vram
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.vramUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.vramTotalBytes)
            }

            Components.PercentBoard {
                visible: Services.SystemMonitor.swapEnabled
                width: parent.width
                height: Services.SystemMonitor.swapEnabled ? 120 : 0
                title: "󰯎  SWAP"
                seriesColor: "#F9E2AF"
                values: Services.SystemMonitor.swapHistory
                currentValue: Services.SystemMonitor.swap
                detailText: Services.SystemMonitor.formatBytes(Services.SystemMonitor.swapUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.swapTotalBytes)
            }

            // SSD — simple bar, not a graph
            Rectangle {
                width: parent.width
                height: 52
                radius: 16
                color: Core.Theme.surface
                border.color: Core.Theme.accent
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 12

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "SSD  " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.diskUsedBytes) + " / " + Services.SystemMonitor.formatBytes(Services.SystemMonitor.diskTotalBytes)
                            color: Core.Theme.foreground
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Services.SystemMonitor.disk + "%"
                            color: Core.Theme.foregroundFaint
                            font.family: Core.Theme.fontFamily
                            font.pixelSize: 10
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
    }
}
