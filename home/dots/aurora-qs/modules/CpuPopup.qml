import QtQuick

import "../core" as Core
import "../services" as Services
import "../components" as Components

Components.PopupSurface {
    id: popup

    popupId: "cpu"
    cardWidth: 360
    maxCardHeight: 420

    contentComponent: Component {
        Column {
            spacing: Core.Theme.spacing

            Components.PopupHeader {
                width: parent.width
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
                width: parent.width
                height: 1
                color: Core.Theme.separator
            }

            Components.PercentBoard {
                width: parent.width
                height: 120
                title: "󰻠  CPU"
                seriesColor: "#CBA6F7"
                values: Services.SystemMonitor.cpuHistory
                currentValue: Services.SystemMonitor.cpu
                detailText: Services.SystemMonitor.temperature < 0 ? "--" : Services.SystemMonitor.temperature + "°C"
            }

            Components.PercentBoard {
                width: parent.width
                height: 120
                title: "󰢮  GPU"
                seriesColor: "#89B4FA"
                values: Services.SystemMonitor.gpuHistory
                currentValue: Services.SystemMonitor.gpu
                detailText: Services.SystemMonitor.gpuTemperature < 0 ? "--" : Services.SystemMonitor.gpuTemperature + "°C"
            }
        }
    }
}
